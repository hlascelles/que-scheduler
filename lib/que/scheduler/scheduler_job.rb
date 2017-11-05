require 'que'
require 'yaml'
require_relative 'schedule_parser'
require_relative 'scheduler_job_args'

module Que
  module Scheduler
    class SchedulerJob < Que::Job
      SCHEDULER_FREQUENCY = 60

      # Highest possible priority.
      @priority = 0

      def run(options = nil, oldarg = nil)
        # Early versions took separate args. We now just pass in a hash.
        options = { last_run_time: options, job_dictionary: oldarg } if oldarg.present?

        ::ActiveRecord::Base.transaction do
          scheduler_job_args = SchedulerJobArgs.prepare_scheduler_job_args(options)
          Que.log(message: "que-scheduler last ran at #{scheduler_job_args.last_run_time}.")
          result = enqueue_required_jobs(scheduler_job_args)
          enqueue_self_again(scheduler_job_args, result.schedule_dictionary)
          destroy
        end
      end

      private

      def enqueue_required_jobs(scheduler_job_args)
        # Obtain the hash of missed jobs. Keys are the job classes, and the values are arrays
        # each containing more arrays for the arguments of that instance.
        result = ScheduleParser.parse(SchedulerJob.scheduler_config, scheduler_job_args)
        result.missed_jobs.each do |job_class, args_arrays|
          args_arrays.each do |args|
            Que.log(message: "que-scheduler enqueueing #{job_class} with args: #{args}")
            job_class.enqueue(*args)
          end
        end
        result
      end

      def enqueue_self_again(scheduler_job_args, new_job_dictionary)
        SchedulerJob.enqueue(
          last_run_time: scheduler_job_args.as_time.iso8601,
          job_dictionary: new_job_dictionary,
          run_at: scheduler_job_args.as_time.beginning_of_minute + SCHEDULER_FREQUENCY
        )
      end

      class << self
        def scheduler_config
          @scheduler_config ||= begin
            location = ENV.fetch('QUE_SCHEDULER_CONFIG_LOCATION', 'config/que_schedule.yml')
            jobs_list(YAML.load_file(location))
          end
        end

        # Convert the config hash into a list of real classes and args, parsing the cron and
        # "unmissable" parameters.
        def jobs_list(schedule)
          schedule.map do |k, v|
            clazz = Object.const_get(v['class'] || k)
            args = v.key?('args') ? v.fetch('args') : []
            unmissable = v['unmissable'] == true
            {
              name: k,
              clazz: clazz,
              args: args,
              cron: v.fetch('cron'),
              unmissable: unmissable
            }
          end
        end
      end
    end
  end
end
