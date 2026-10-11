# typed: true

require "que"
require "sorbet-runtime"
require_relative "db_support"
require_relative "types"

module Que
  module Scheduler
    # :reek:Attribute
    class Configuration
      extend T::Sig

      sig { returns(T.any(String, Pathname)) }
      attr_accessor :schedule_location

      sig { returns(T.nilable(Types::SCHEDULE_CONFIG)) }
      attr_accessor :schedule

      sig { returns(T.any(Method, Proc)) }
      attr_accessor :transaction_adapter

      sig { returns(String) }
      attr_accessor :que_scheduler_queue

      sig { returns(T.nilable(String)) }
      attr_accessor :time_zone
    end

    class << self
      extend T::Sig

      sig { returns(Configuration) }
      def configuration
        @configuration ||= Configuration.new
      end

      sig { params(blk: T.proc.params(config: Configuration).void).void }
      def configure(&blk)
        yield(configuration)
      end

      sig { void }
      def apply_defaults
        configure do |config|
          config.schedule_location =
            ENV.fetch("QUE_SCHEDULER_CONFIG_LOCATION", "config/que_schedule.yml")
          config.transaction_adapter = ::Que.method(:transaction)
          config.que_scheduler_queue =
            ENV.fetch("QUE_SCHEDULER_QUEUE", Que::DEFAULT_QUEUE)
          config.schedule = nil
          config.time_zone = nil
        end
      end
    end
  end
end

Que::Scheduler.apply_defaults
