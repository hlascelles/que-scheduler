require 'bundler/setup'

ENV['QUE_SCHEDULER_CONFIG_LOCATION'] = "#{__dir__}/config/que_schedule.yml"

require 'que/scheduler'
require 'pry-byebug'

Dir["#{__dir__}/../spec/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.full_backtrace = true
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
