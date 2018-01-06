require 'que'

require_relative 'schedule_parser'
require_relative 'enqueueing_calculator'
require_relative 'scheduler_job_args'

module Que
  module Scheduler
    class SchedulerJob < Que::Job
      SCHEDULER_COUNT_SQL = "SELECT COUNT(*) FROM que_jobs WHERE job_class = '#{name}'".freeze
      SCHEDULER_FREQUENCY = 60

      # Always highest possible priority.
      @priority = 0

      def run(options = nil)
        ::ActiveRecord::Base.transaction do
          assert_one_scheduler_job
          scheduler_job_args = SchedulerJobArgs.build(options)
          logs = ["que-scheduler last ran at #{scheduler_job_args.last_run_time}."]

          # It's possible one worker node has severe clock skew, and reports a time earlier than
          # the last run. If so, log, and rescheduled with the same last run at.
          if scheduler_job_args.as_time < scheduler_job_args.last_run_time
            handle_clock_skew(scheduler_job_args, logs)
          else
            # Otherwise, run as normal
            handle_normal_call(scheduler_job_args, logs)
          end

          # Only now we're sure nothing errored, log the results
          logs.each { |str| Que.log(message: str) }
          destroy
        end
      end

      private

      def assert_one_scheduler_job
        schedulers = ActiveRecord::Base.connection.execute(SCHEDULER_COUNT_SQL).first['count'].to_i
        return if schedulers == 1
        raise "Only one #{self.class.name} should be enqueued. #{schedulers} were found."
      end

      def handle_normal_call(scheduler_job_args, logs)
        result = enqueue_required_jobs(scheduler_job_args, logs)
        enqueue_self_again(
          scheduler_job_args.as_time,
          scheduler_job_args.as_time,
          result.schedule_dictionary
        )
      end

      def enqueue_required_jobs(scheduler_job_args, logs)
        # Obtain the hash of missed jobs. Keys are the job classes, and the values are arrays
        # each containing more arrays for the arguments of that instance.
        result = EnqueueingCalculator.parse(ScheduleParser.defined_jobs, scheduler_job_args)
        result.missed_jobs.each do |job_class, args_arrays|
          args_arrays.each do |args|
            logs << "que-scheduler enqueueing #{job_class} with args: #{args}"
            job_class.enqueue(*args)
          end
        end
        result
      end

      def handle_clock_skew(scheduler_job_args, logs)
        logs << 'que-scheduler detected worker with time older than last run. ' \
                    'Rescheduling without enqueueing jobs.'
        enqueue_self_again(
          scheduler_job_args.last_run_time,
          scheduler_job_args.as_time,
          scheduler_job_args.job_dictionary
        )
      end

      def enqueue_self_again(last_full_execution, this_run_time, new_job_dictionary)
        SchedulerJob.enqueue(
          last_run_time: last_full_execution.iso8601,
          job_dictionary: new_job_dictionary,
          run_at: this_run_time.beginning_of_minute + SCHEDULER_FREQUENCY
        )
      end
    end
  end
end
