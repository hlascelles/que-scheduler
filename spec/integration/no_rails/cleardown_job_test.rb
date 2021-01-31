require_relative "integration_setup"

# This test is primarily to check that the que job that the gem provides can run successfully under
# all Que versions. Specifically since it reads the args during the run method, and they change
# format between Que 0.x and 1.x.

IntegrationSetup.setup_db

# que-scheduler setup
Que::Scheduler.configure do |config|
  config.schedule = {
    TestQueSchedulerAuditClearDownJob: {
      cron: "* * * * *",
      class: Que::Scheduler::Jobs::QueSchedulerAuditClearDownJob,
      args: {
        retain_row_count: 0,
      },
    },
  }
  config.time_zone = "Europe/London"
end

IntegrationSetup.trigger_scheduler

# Now "run that job that was scheduled"
IntegrationSetup.run_a_job

puts "Success"
