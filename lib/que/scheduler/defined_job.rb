require 'dry-struct'
require 'fugit'

# This is the definition of one scheduled job in the yml file.
module Que
  module Scheduler
    class DefinedJob < Dry::Struct::Value
      constructor_type :schema

      attribute :name, Dry::Types['strict.string']
      attribute :job_class, Dry::Types['strict.class']
      attribute :cron, Dry::Types::Constructor.new(Fugit::Cron) { |cron|
        f = Fugit::Cron.new(cron)
        if f.nil?
          raise "que-scheduler config has invalid cron '#{cron}' in " \
                "#{QUE_SCHEDULER_CONFIG_LOCATION}"
        end
        f
      }
      attribute :queue, Dry::Types['strict.string'].optional
      attribute :priority, Dry::Types['strict.int'].constrained(gteq: 0).optional
      attribute :args, Dry::Types['strict.array'].optional
      attribute :unmissable, Dry::Types['strict.bool'].default(false)

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
