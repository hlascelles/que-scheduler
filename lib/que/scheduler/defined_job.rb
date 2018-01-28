require 'hashie'
require 'fugit'
require 'backports/2.4.0/hash/compact'

# This is the definition of one scheduleable job in the que-scheduler config yml file.
module Que
  module Scheduler
    class DefinedJob < Hashie::Dash
      QUE_SCHEDULER_CONFIG_LOCATION =
        ENV.fetch('QUE_SCHEDULER_CONFIG_LOCATION', 'config/que_schedule.yml')

      include Hashie::Extensions::Dash::PropertyTranslation

      SCHEDULE_TYPES = [
        SCHEDULE_TYPE_DEFAULT = :default,
        SCHEDULE_TYPE_EVERY_EVENT = :every_event
      ].freeze

      def self.err_field(f, v)
        suffix = "in que-scheduler config #{QUE_SCHEDULER_CONFIG_LOCATION}"
        raise "Invalid #{f} '#{v}' #{suffix}"
      end

      property :name, required: true
      property :job_class, required: true, transform_with: lambda { |v|
        job_class = Object.const_get(v)
        job_class < Que::Job ? job_class : err_field(:job_class, v)
      }
      property :cron, transform_with: ->(v) { Fugit::Cron.new(v) || err_field(:cron, v) }
      property :queue, transform_with: ->(v) { v.is_a?(String) ? v : err_field(:queue, v) }
      property :priority, transform_with: ->(v) { v.is_a?(Integer) ? v : err_field(:priority, v) }
      property :args
      property :schedule_type, default: SCHEDULE_TYPE_DEFAULT, transform_with: lambda { |v|
        v.to_sym.tap { |vs| SCHEDULE_TYPES.include?(vs) || err_field(:schedule_type, v) }
      }

      # Given a "last time", return the next Time the event will occur, or nil if it
      # is after "to".
      def next_run_time(from, to)
        next_time = cron.next_time(from)
        next_run = next_time.to_local_time.in_time_zone(next_time.zone)
        next_run <= to ? next_run : nil
      end

      # Given the last scheduler run time, and this run time, return all
      # the instances that should be enqueued for the job class.
      def calculate_missed_runs(last_run_time, as_time)
        missed_times = []
        last_time = last_run_time
        while (next_run = next_run_time(last_time, as_time))
          missed_times << next_run
          last_time = next_run
        end

        generate_required_jobs_list(missed_times)
      end

      class << self
        def defined_jobs
          @defined_jobs ||= YAML.safe_load(IO.read(QUE_SCHEDULER_CONFIG_LOCATION)).map do |k, v|
            Que::Scheduler::DefinedJob.new(
              {
                name: k,
                job_class: v['class'] || k,
                queue: v['queue'],
                args: v['args'],
                priority: v['priority'],
                cron: v['cron'],
                schedule_type: v['schedule_type'] || DefinedJob::SCHEDULE_TYPE_DEFAULT
              }.compact
            )
          end
        end
      end

      private

      # Given the timestamps of the missed events, generate a list of jobs
      # that can be enqueued as an array of arrays of args.
      def generate_required_jobs_list(missed_times)
        jobs_for_class = []

        unless missed_times.empty?
          options = {
            args: args,
            queue: queue,
            priority: priority
          }.compact

          if schedule_type == DefinedJob::SCHEDULE_TYPE_EVERY_EVENT
            missed_times.each do |time_missed|
              jobs_for_class << options.merge(args: [time_missed] + (args || []))
            end
          else
            jobs_for_class << options
          end
        end
        jobs_for_class
      end
    end
  end
end
