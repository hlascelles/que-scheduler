require 'que'
require 'yaml'
require_relative 'schedule_parser'

module Que
  module Scheduler
    class SchedulerJob < Que::Job
      # Highest possible priority.
      @priority = 0

      def run(last_time = nil, known_jobs = [])
        ::ActiveRecord::Base.transaction do
          last_time = last_time.nil? ? Time.now : Time.zone.parse(last_time)
          as_time = Time.now

          Que.log({ message: "que-scheduler last ran at #{last_time}." })

          result =
            ScheduleParser.parse(SchedulerJob.scheduler_config, as_time, last_time, known_jobs)
          result.missed_jobs.each do |job_class, args_arrays|
            args_arrays.each { |args|
              Que.log({ message: "que-scheduler enqueueing #{job_class} with args: #{args}" })
              job_class.enqueue(*args)
            }
          end

          SchedulerJob.enqueue(
            as_time,
            result.schedule_dictionary,
            run_at: as_time + result.seconds_until_next_job
          )
          destroy
        end
      end

      class << self
        def scheduler_config
          @scheduler_config ||= begin
            location = ENV.fetch('QUE_SCHEDULER_CONFIG_LOCATION', 'config/que_schedule.yml')
            jobs_list(YAML.load_file(location))
          end
        end

        # Convert the config hash into a list of real classes and args, parsing the cron and
        # unmissable parameters.
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
