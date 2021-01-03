require "que"
require_relative "version_support"

module Que
  module Scheduler
    class Configuration
      attr_accessor :schedule_location
      attr_accessor :schedule
      attr_accessor :transaction_adapter
      attr_accessor :que_scheduler_queue
      attr_accessor :time_zone
    end

    class << self
      attr_accessor :configuration

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
