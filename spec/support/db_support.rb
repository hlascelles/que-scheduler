require "active_record"

module DbSupport
  class << self
    RSpec::Mocks::Syntax.enable_expect(self)

    def setup_db
      testing_db = "que_scheduler_testing"
      db_config = {
        adapter: "postgresql",
        database: testing_db,
        username: "postgres",
        password: ENV.fetch("DB_PASSWORD", "postgres"),
        host: ENV.fetch("DB_HOST", "127.0.0.1"),
        port: ENV.fetch("DB_PORT", 5432),
        reconnect: true,
      }
      ActiveRecord::Base.establish_connection(db_config.merge(database: "postgres"))

      conn = ActiveRecord::Base.connection
      if conn.execute("SELECT 1 from pg_database WHERE datname='#{testing_db}';").any?
        conn.execute("DROP DATABASE #{testing_db}")
      end
      conn.execute("CREATE DATABASE #{testing_db}")

      ActiveRecord::Base.establish_connection(db_config)
      Que.connection = ActiveRecord

      # First migrate Que
      Que.migrate!(version: ::Que::Migrations::CURRENT_VERSION)

      # Now migrate que scheduler
      Que::Scheduler::Migrations.migrate!(version: Que::Scheduler::Migrations::MAX_VERSION)
      Que::Scheduler::Migrations.reenqueue_scheduler_if_missing

      puts "Setting DB timezone to #{::Time.zone.tzinfo.identifier}"
      Que::Scheduler::DbSupport.execute("set timezone TO '#{::Time.zone.tzinfo.identifier}';")
    end

    def jobs_by_class(clazz)
      Que::Scheduler::DbSupport.execute("SELECT * FROM que_jobs where job_class = '#{clazz}'")
    end

    def column_default(table, column_name)
      Que::Scheduler::DbSupport.execute(%{
        SELECT column_name, column_default
        FROM information_schema.columns
        WHERE (table_schema, table_name, column_name) = ('public', '#{table}', '#{column_name}')
      }).first.fetch(:column_default)
    end

    def mock_db_time_now
      # We cannot Timecop freeze the DB clock, so we must override the now lookup.
      allow(Que::Scheduler::Db).to receive(:now).and_return(Time.zone.now)
    end

    def scheduler_job_id_type
      Que::Scheduler::DbSupport.execute(
        "select column_name, data_type from information_schema.columns " \
        "where table_name = 'que_scheduler_audit';"
      ).find { |row| row.fetch(:column_name) == "scheduler_job_id" }.fetch(:data_type)
    end

    def enqueued_table_exists?
      ActiveRecord::Base.connection.table_exists?(Que::Scheduler::Audit::ENQUEUED_TABLE_NAME)
    end

    # When a jsonb column is populated with an array, then when it is selected from the
    # DB with Que.execute the value differs by Que. For Que 0.x it comes out as a String. For 1.x
    # it is parsed into an array here: https://t.ly/byDJd. This helper equalises them.
    def convert_args_column(db_jobs)
      db_jobs.map do |row|
        var = row[:args]
        row[:args] = JSON.parse(var) if var.is_a?(String) && var.start_with?("[")
        row
      end
    end

    def primary_key_exists?(table_name)
      result = Que::Scheduler::DbSupport.execute(<<~SQL)
        SELECT * FROM information_schema.table_constraints
        WHERE table_name = '#{table_name}' AND constraint_type = 'PRIMARY KEY';
      SQL
      result.any?
    end
  end
end
