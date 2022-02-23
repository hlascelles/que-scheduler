require "bundler/setup"

require "pry-byebug"
require "coveralls"
Coveralls.wear!

# By default, que-scheduler specs run in different timezones with every execution, thanks to
# zonebie. If you want to force one particular timezone, you can use the following:
# ENV['ZONEBIE_TZ'] = 'International Date Line West'
# Require zonebie before most other gems to ensure it sets the correct test timezone.
if ENV["CI"].present?
  # Changing the TZ in CI builds has proved to be hard, if not impossible. So, on CI only, shift
  # zonebie to using what is already present. For local builds, let zonebie randomise it.
  tz_identifier = `cat /etc/timezone`.strip
  puts "TZ appears to be #{tz_identifier}"
  ENV["ZONEBIE_TZ"] = tz_identifier
end
require "zonebie/rspec"

# Enforce load order here due to https://github.com/que-rb/que/issues/284
if Gem.loaded_specs["rails"]
  require "rails"
  require "rails/railtie"
end
if Gem.loaded_specs["activejob"]
  require "active_job"
  require "active_job/queue_adapters/que_adapter"
end

Bundler.require :default, :development

Dir["#{__dir__}/../spec/support/**/*.rb"].sort.each { |f| require f }

if RUBY_VERSION.start_with?("3") && Gem.loaded_specs["activesupport"].version.to_s.start_with?("5")
  puts "Rails 5 does not work with Ruby 3"
  # Allow the CI to continue the ruby test matrix
  # rubocop:disable Style/SymbolProc
  RSpec.configure do |config|
    config.around(:each) do |example|
      example.skip
    end
  end
  # rubocop:enable Style/SymbolProc
  return
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.full_backtrace = true
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.before do
    ::Que.clear!
    qsa = Que::Scheduler::VersionSupport.execute("select * from que_scheduler_audit")
    expect(qsa.count).to eq(0)
    qsae = Que::Scheduler::VersionSupport.execute("select * from que_scheduler_audit_enqueued")
    expect(qsae.count).to eq(0)
  end

  config.before do
    if Que::Scheduler::Schedule.instance_variable_defined?("@schedule")
      Que::Scheduler::Schedule.remove_instance_variable("@schedule")
    end
    Que::Scheduler.apply_defaults
    Que::Scheduler.configure do |scheduler_config|
      scheduler_config.schedule_location = "#{__dir__}/config/que_schedule.yml"
    end
  end

  config.before(:suite) do
    DbSupport.setup_db
  end
  config.around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = 1000
