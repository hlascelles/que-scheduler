require 'bundler/setup'

require 'coveralls'
Coveralls.wear!

ENV['QUE_SCHEDULER_CONFIG_LOCATION'] = "#{__dir__}/config/que_schedule.yml"

# By default, que-scheduler specs run in different timezones with every execution, thanks to
# zonebie. If you want to force one particular timezone, you can use the following:
# ENV['ZONEBIE_TZ'] = 'International Date Line West'

require 'zonebie/rspec'
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
