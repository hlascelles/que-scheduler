require_relative 'defined_job'

module Que
  module Scheduler
    class Schedule
      class << self
        def schedule
          @schedule ||=
            begin
              location = Que::Scheduler.configuration.schedule_location
              from_file(location)
            end
        end

        def from_file(location)
          yml = IO.read(location)
          config_hash = YAML.safe_load(yml)
          from_hash(config_hash)
        end

        def from_hash(config_hash)
          config_hash.map do |name, defined_job_hash|
            [name, hash_item_to_defined_job(name, defined_job_hash)]
          end.to_h
        end

        private

        def hash_item_to_defined_job(name, defined_job_hash)
          Que::Scheduler::DefinedJob.create(
            name: name,
            job_class: defined_job_hash['class'] || name,
            queue: defined_job_hash['queue'],
            args: defined_job_hash['args'],
            priority: defined_job_hash['priority'],
            cron: defined_job_hash['cron'],
            schedule_type: defined_job_hash['schedule_type']&.to_sym,
          )
        end
      end
    end

    class << self
      def schedule
        Schedule.schedule
      end
    end
  end
end
