require 'que'
require_relative 'version_support'

module Que
  module Scheduler
    class << self
      attr_accessor :configuration
    end

    def self.configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end

    class Configuration
      attr_accessor :schedule_location
      attr_accessor :transaction_adapter
      attr_accessor :que_scheduler_queue
    end
  end
end

Que::Scheduler.configure do |config|
  config.schedule_location = ENV.fetch('QUE_SCHEDULER_CONFIG_LOCATION', 'config/que_schedule.yml')
  config.transaction_adapter = ::Que.method(:transaction)
  config.que_scheduler_queue = Que::Scheduler::VersionSupport.default_scheduler_queue
end
