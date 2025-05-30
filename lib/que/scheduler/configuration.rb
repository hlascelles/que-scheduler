require "que"
require_relative "version_support"

module Que
  module Scheduler
    # :reek:Attribute
    class Configuration
      attr_accessor :schedule_location, :schedule, :transaction_adapter, :que_scheduler_queue,
                    :time_zone
    end

    class << self
      # :reek:Attribute
      attr_accessor :configuration # rubocop:disable ThreadSafety/ClassAndModuleAttributes

      def configure
        self.configuration ||= Configuration.new
        yield(configuration)
      end

      def apply_defaults
        configure do |config|
          config.schedule_location =
            ENV.fetch("QUE_SCHEDULER_CONFIG_LOCATION", "config/que_schedule.yml")
          config.transaction_adapter = ::Que.method(:transaction)
          config.que_scheduler_queue =
            ENV.fetch("QUE_SCHEDULER_QUEUE", Que::Scheduler::VersionSupport.default_scheduler_queue)
          config.schedule = nil
          config.time_zone = nil
        end
      end
    end
  end
end

Que::Scheduler.apply_defaults
