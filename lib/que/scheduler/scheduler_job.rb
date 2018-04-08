require 'que'

require_relative 'defined_job'
require_relative 'enqueueing_calculator'
require_relative 'scheduler_job_args'

# The main job that runs every minute, determining what needs to be enqueued, enqueues the required
# jobs, then re-enqueues itself.
module Que
  module Scheduler
    class SchedulerJob < Que::Job
      SCHEDULER_FREQUENCY = 60

      # Always highest possible priority.
      @priority = 0

      def run(options = nil)
        ::Que::Scheduler::Adapters::Orm.instance.transaction do
          assert_one_scheduler_job
          scheduler_job_args = SchedulerJobArgs.build(options)
          logs = ["que-scheduler last ran at #{scheduler_job_args.last_run_time}."]

          # It's possible the DB time has been changed manaully to an earlier time than it was
          # before. Whether this was a small amount of time (eg clock drift correction), or a major
          # change like timezone, the business schedule semantics of this are unknowable, so log and
          # rescheduled with the same last run at.
          if scheduler_job_args.as_time < scheduler_job_args.last_run_time
            handle_db_clock_change_backwards(scheduler_job_args, logs)
          else
            # Otherwise, run as normal
            handle_normal_call(scheduler_job_args, logs)
          end

          # Only now we're sure nothing errored, log the results
          logs.each { |str| Que.log(message: str) }
          destroy
        end
      end

      def enqueue_required_jobs(result, logs)
        result.missed_jobs.each do |job_class, to_enqueue_list|
          to_enqueue_list.each do |to_enqueue|
            enqueue_new_job(job_class, to_enqueue.to_h, logs)
          end
        end
        result.schedule_dictionary
      end

      private

      def assert_one_scheduler_job
        schedulers = ::Que::Scheduler::Adapters::Orm.instance.count_schedulers
        return if schedulers == 1
        raise "Only one #{self.class.name} should be enqueued. #{schedulers} were found."
      end

      def handle_normal_call(scheduler_job_args, logs)
        # Obtain the hash of missed jobs. Keys are the job classes, and the values are arrays
        # each containing params to enqueue.
        result = EnqueueingCalculator.parse(DefinedJob.defined_jobs, scheduler_job_args)
        new_job_dictionary = enqueue_required_jobs(result, logs)
        enqueue_self_again(
          scheduler_job_args.as_time,
          scheduler_job_args.as_time,
          new_job_dictionary
        )
      end

      def enqueue_new_job(job_class, to_enqueue, logs)
        logs << "que-scheduler enqueueing #{job_class} with: #{to_enqueue}"
        args = to_enqueue.delete(:args)
        if args.is_a?(Hash)
          job_class.enqueue(args.merge(to_enqueue))
        else
          job_class.enqueue(*args, to_enqueue)
        end
      end

      def handle_db_clock_change_backwards(scheduler_job_args, logs)
        logs << 'que-scheduler detected the DB time is further back than the last run. ' \
                'Rescheduling self again without enqueueing jobs to wait for the clock to catch up.'
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
