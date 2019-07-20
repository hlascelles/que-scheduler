require 'active_record'

module DbSupport
  class << self
    RSpec::Mocks::Syntax.enable_expect(self)

    def setup_db
      testing_db = 'que_scheduler_testing'
      db_config = {
        adapter: 'postgresql',
        database: testing_db,
        username: 'postgres',
        password: ENV.fetch('DB_PASSWORD'),
        host: ENV.fetch('DB_HOST', '127.0.0.1'),
        port: ENV.fetch('DB_PORT', 5432),
        reconnect: true,
      }
      ActiveRecord::Base.establish_connection(db_config.merge(database: 'postgres'))
      conn = ActiveRecord::Base.connection
      if conn.execute("SELECT 1 from pg_database WHERE datname='#{testing_db}';").count > 0
        conn.execute("DROP DATABASE #{testing_db}")
      end
      conn.execute("CREATE DATABASE #{testing_db}")

      ActiveRecord::Base.establish_connection(db_config)
      Que.mode = :off
      Que.connection = ActiveRecord
      Que.migrate!(version: 3)
      Que::Scheduler::Migrations.migrate!(version: Que::Scheduler::Migrations::MAX_VERSION)
      puts "Setting DB timezone to #{::Time.zone.tzinfo.identifier}"
      Que::Scheduler::VersionSupport.execute("set timezone TO '#{::Time.zone.tzinfo.identifier}';")
    end

    def jobs_by_class(clazz)
      Que::Scheduler::VersionSupport.execute("SELECT * FROM que_jobs where job_class = '#{clazz}'")
    end

    def column_default(table, column_name)
      Que::Scheduler::VersionSupport.execute(%{
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
      Que::Scheduler::VersionSupport.execute(
        'select column_name, data_type from information_schema.columns ' \
        "where table_name = 'que_scheduler_audit';"
      ).find { |row| row.fetch(:column_name) == 'scheduler_job_id' }.fetch(:data_type)
    end

    def enqueued_table_exists?
      ActiveRecord::Base.connection.table_exists?(Que::Scheduler::Audit::ENQUEUED_TABLE_NAME)
    end
  end
end
