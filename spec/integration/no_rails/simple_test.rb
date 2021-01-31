require_relative "integration_setup"

IntegrationSetup.setup_db

# que-scheduler setup
# Test Jobs
class TestNoRailsJob < ::Que::Job
  cattr_accessor :test_job_ran_result

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

# Note the key "foo" is a string under Que 0.x, but a symbol in Que 1.x
expected =
  if Que::Scheduler::VersionSupport.zero_major?
    { "foo" => "bar" }
  else
    { foo: "bar" }
  end
unless TestNoRailsJob.test_job_ran_result == expected
  raise "Test run did not yield expected args: #{TestNoRailsJob.test_job_ran_result}"
end

puts "Success"
