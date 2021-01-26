require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "que", "~> 0.14"
  gem "que-scheduler", path: "../../../"
  gem "activerecord", "~> 5.2"
  gem "pg"
end

require "que"
require "que-scheduler"
require "active_record"

# Test Jobs
class TestNoRailsJob < ::Que::Job
  def run; end
end

# Migrations
db_config = {
  adapter: "postgresql",
  database: "testing_db",
  username: "postgres",
  password: "postgres",
  host: ENV["CI"] ? "postgres" : "127.0.0.1",
  port: ENV["CI"] ? 5432 : 5430,
  reconnect: true,
}.stringify_keys
ActiveRecord::Base.establish_connection(db_config.merge("database" => "postgres"))
ActiveRecord::Base.connection.drop_database(db_config["database"])
ActiveRecord::Base.connection.create_database(db_config["database"])
ActiveRecord::Base.establish_connection(db_config)
Que.connection = ActiveRecord
Que.migrate!(version: 3)

# que-scheduler setup
Que::Scheduler.configure do |config|
  config.schedule = {
    TestNoRailsJob: {
      cron: "* * * * *",
    },
  }
  config.time_zone = "Europe/London"
end
Que::Scheduler::Migrations.migrate!(version: Que::Scheduler::Migrations::MAX_VERSION)

def run_a_job
  puts "Running job..."
  result = ::Que::Job.work
  puts result
  raise "Job errored: #{result}" unless result[:event] == :job_worked
end

puts Time.zone

# We now want to run the scheduler job in a way so that it isn't the first run where it loads the
# dictionary (but the second one) where it actually enqueues things.
run_a_job # Sets up the scheduler
Que::Scheduler::VersionSupport.execute("UPDATE que_jobs SET run_at = '2020-01-01'")
run_a_job # "Runs" it to enqueue something

puts "Success"
