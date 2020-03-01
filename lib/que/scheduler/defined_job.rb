require 'hashie'
require 'fugit'
require 'backports/2.4.0/hash/compact'

# This is the definition of one scheduleable job in the que-scheduler config yml file.
module Que
  module Scheduler
    class DefinedJob < Hashie::Dash
      include Hashie::Extensions::Dash::PropertyTranslation

      DEFINED_JOB_TYPES = [
        DEFINED_JOB_TYPE_DEFAULT = :default,
        DEFINED_JOB_TYPE_EVERY_EVENT = :every_event,
      ].freeze

      property :name, required: true
      property :job_class, required: true, transform_with: lambda { |v|
        job_class = Object.const_get(v)
        job_class < Que::Job ? job_class : err_field(:job_class, v)
      }
      property :cron, required: true, transform_with: lambda { |v|
        Fugit::Cron.parse(v) || err_field(:cron, v)
      }
      property :queue, transform_with: ->(v) { v.is_a?(String) ? v : err_field(:queue, v) }
      property :priority, transform_with: ->(v) { v.is_a?(Integer) ? v : err_field(:priority, v) }
      property :args
      property :schedule_type, default: DEFINED_JOB_TYPE_DEFAULT, transform_with: lambda { |v|
        v.to_sym.tap { |vs| DEFINED_JOB_TYPES.include?(vs) || err_field(:schedule_type, v) }
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

        generate_to_enqueue_list(missed_times)
      end

      class << self
        private

        def err_field(field, value)
          schedule = Que::Scheduler.configuration.schedule_location
          raise "Invalid #{field} '#{value}' in que-scheduler schedule #{schedule}"
        end
      end

      private

      class ToEnqueue < Hashie::Dash
        property :args, required: true, default: []
        property :queue
        property :priority
        property :job_class, required: true
      end

      def generate_to_enqueue_list(missed_times)
        return [] if missed_times.empty?

        options = to_h.slice(:args, :queue, :priority, :job_class).compact
        args_array = args.is_a?(Array) ? args : Array(args)

        if schedule_type == DefinedJob::DEFINED_JOB_TYPE_EVERY_EVENT
          missed_times.map do |time_missed|
            ToEnqueue.new(options.merge(args: [time_missed] + args_array))
          end
        else
          [ToEnqueue.new(options.merge(args: args_array))]
        end
      end
    end
  end
end
