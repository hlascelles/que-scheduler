require 'hashie'
require 'fugit'

# This is the definition of one scheduleable job in the que-scheduler config yml file.
module Que
  module Scheduler
    class DefinedJob < Hashie::Dash
      include Hashie::Extensions::Dash::PropertyTranslation

      def self.err_field(f, v)
        suffix = 'in que-scheduler config ' \
                 "#{Que::Scheduler::ScheduleParser::QUE_SCHEDULER_CONFIG_LOCATION}"
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
      property :unmissable, default: false

      # Given a "last time", return the next Time the event will occur, or nil if it
      # is after "to".
      def next_run_time(from, to)
        next_time = cron.next_time(from)
        next_run = next_time.to_local_time.in_time_zone(next_time.zone)
        next_run <= to ? next_run : nil
      end
    end
  end
end
