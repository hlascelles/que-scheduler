require 'yaml'
require 'backports/2.4.0/hash/compact'

require_relative 'defined_job'

module Que
  module Scheduler
    module ScheduleParser
      QUE_SCHEDULER_CONFIG_LOCATION =
        ENV.fetch('QUE_SCHEDULER_CONFIG_LOCATION', 'config/que_schedule.yml')

      class << self
        def scheduler_config
          @scheduler_config ||= begin
            jobs_list(YAML.load_file(QUE_SCHEDULER_CONFIG_LOCATION))
          end
        end

        # Convert the config hash into a list of real classes and args, parsing the cron and
        # "unmissable" parameters.
        def jobs_list(schedule)
          schedule.map do |k, v|
            Que::Scheduler::DefinedJob.new(
              {
                name: k,
                job_class: v['class'] || k,
                queue: v['queue'],
                args: v['args'],
                priority: v['priority'],
                cron: v['cron'],
                unmissable: v['unmissable']
              }.compact
            )
          end
        end
      end
    end
  end
end
