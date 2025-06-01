require_relative "integration_setup"

IntegrationSetup.setup_db

# que-scheduler setup
# Test Jobs
class TestNoRailsJob < ::Que::Job
  cattr_accessor :test_job_ran_result # rubocop:disable ThreadSafety/ClassAndModuleAttributes

  # :reek:UtilityFunction
  def run(args)
    TestNoRailsJob.test_job_ran_result = args
  end
end

Que::Scheduler.configure do |config|
  config.schedule = {
    TestNoRailsJob: {
      cron: "* * * * *",
      args: {
        foo: "bar",
      },
    },
  }
  config.time_zone = "Europe/London"
end

IntegrationSetup.trigger_scheduler

# Now "run that job that was scheduled"
IntegrationSetup.run_a_job

expected = { foo: "bar" }
unless TestNoRailsJob.test_job_ran_result == expected
  raise "Test run did not yield expected args: #{TestNoRailsJob.test_job_ran_result}"
end

puts "Success"
