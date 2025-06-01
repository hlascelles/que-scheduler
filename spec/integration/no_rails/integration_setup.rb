require "logger" # https://stackoverflow.com/a/79379493/1267203

module IntegrationSetup
  class << self
    def setup_db
      inline_bundler_setup

      # Migrations
      db_config = {
        adapter: "postgresql",
        database: "integration_test_db",
        username: "postgres",
        password: "postgres",
        host: "127.0.0.1",
        port: ENV["CI"] ? 5432 : 5430,
        reconnect: true,
      }.stringify_keys
      ActiveRecord::Base.establish_connection(db_config.merge("database" => "postgres"))
      ActiveRecord::Base.connection.drop_database(db_config["database"])
      ActiveRecord::Base.connection.create_database(db_config["database"])
      ActiveRecord::Base.establish_connection(db_config)
      Que.connection = ActiveRecord
      Que.migrate!(version: ::Que::Migrations::CURRENT_VERSION)
      Que::Scheduler::Migrations.migrate!(version: Que::Scheduler::Migrations::MAX_VERSION)
    end

    def trigger_scheduler
      puts "Ruby version: #{RUBY_VERSION}"
      puts "Ruby 'now':   #{Time.zone}"

      # We now want to run the scheduler job once where it loads the dictionary, then again when
      # it actually enqueues things.

      # Sets up the scheduler
      IntegrationSetup.run_a_job

      # Make it think it is "late"
      make_scheduler_last_run(Date.yesterday.to_s)

      # "Runs" the scheduler to enqueue something
      IntegrationSetup.run_a_job

      # Make it think it is "too early" so we can focus on what it just enqueued
      make_scheduler_last_run(Date.tomorrow.to_s)
    end

    def run_a_job
      puts "Running job..."
      result = SyncJobWorker.work_job
      puts result.inspect
    end

    # :reek:TooManyStatements
    private def inline_bundler_setup
      require "bundler/inline"

      gemfile do
        source "https://rubygems.org"
        gem "que", ENV.fetch("QUE_VERSION") { ENV["CI"] ? "MISSING IN CI!" : "2.4.1" }
        gem "que-scheduler", path: "../../../"
        gem "activerecord", ENV.fetch("ACTIVE_RECORD_VERSION")
        # Ruby 3.4 needs this gem for specs, otherwise we see "cannot load such file -- base64"
        gem "base64"
        # Ruby 3.4 needs this gem for specs, otherwise we see "cannot load such file -- bigdecimal"
        gem "bigdecimal"
        gem "pg"
        gem "pry-byebug"
        # Ruby 3.4 needs this gem for specs, otherwise we see "cannot load such file -- mutex_m"
        gem "mutex_m"
      end

      require "que"
      require "que-scheduler"
      require "active_record"
      require "pry-byebug"
      require_relative "../../support/sync_job_worker"
    end

    # This moves the last run of the scheduler to a set time. We must both move the que job
    # last_run, and also the internal knowledge "last_run_time" which could be different
    # if the job errors.
    private def make_scheduler_last_run(time)
      Que::Scheduler::DbSupport.execute(<<~SQL)
        UPDATE que_jobs SET run_at = '#{time}'
        WHERE job_class = 'Que::Scheduler::SchedulerJob'
      SQL
      args = Que::Scheduler::DbSupport.execute(<<~SQL).first[:args]
        SELECT * FROM que_jobs WHERE job_class = 'Que::Scheduler::SchedulerJob'
      SQL
      args.first["last_run_time"] = time
      Que::Scheduler::DbSupport.execute(<<~SQL)
        UPDATE que_jobs
        SET args = '#{args.to_json}'
        WHERE job_class = 'Que::Scheduler::SchedulerJob'
      SQL
    end
  end
end
