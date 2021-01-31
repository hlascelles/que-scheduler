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
        host: ENV["CI"] ? "postgres" : "127.0.0.1",
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
      yesterday = Date.yesterday.to_s

      # We now want to run the scheduler job once where it loads the dictionary, then again when
      # it actually enqueues things.

      # Sets up the scheduler
      IntegrationSetup.run_a_job

      # Make it think it is "late"
      Que::Scheduler::VersionSupport.execute("UPDATE que_jobs SET run_at = '#{yesterday}'")
      args = Que::Scheduler::VersionSupport.execute("SELECT * FROM que_jobs").first[:args]
      args.first["last_run_time"] = yesterday
      Que::Scheduler::VersionSupport.execute("UPDATE que_jobs SET args = '#{args.to_json}'")

      # "Runs" the scheduler to enqueue something
      IntegrationSetup.run_a_job
    end

    def run_a_job
      puts "Running job..."
      result = SyncJobWorker.work_job
      puts result.inspect
    end

    private

    def inline_bundler_setup
      require "bundler/inline"

      gemfile do
        source "https://rubygems.org"
        gem "que", ENV.fetch("QUE_VERSION") { ENV["CI"] ? "MISSING IN CI!" : "0.14.3" }
        gem "que-scheduler", path: "../../../"
        gem "activerecord", "~> 5.2"
        gem "pg"
        gem "pry-byebug"
      end

      require "que"
      require "que-scheduler"
      require "active_record"
      require "pry-byebug"
      require_relative "../../support/sync_job_worker"
    end
  end
end
