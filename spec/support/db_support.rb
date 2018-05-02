require 'active_record'

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
  # rubocop:disable Lint/HandleExceptions
  begin
    conn.execute("DROP DATABASE #{testing_db}")
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    # Nothing to drop
  end
  # rubocop:enable Lint/HandleExceptions
  conn.execute("CREATE DATABASE #{testing_db}")

  ActiveRecord::Base.establish_connection(db_config)
  Que.mode = :off
  Que.connection = ActiveRecord
  Que.migrate!(version: 3)
  Que::Scheduler::Migrations.migrate!(version: Que::Scheduler::Migrations::MAX_VERSION)
  Que.execute("set timezone TO '#{::Time.zone.tzinfo.identifier}';")
end

def jobs_by_class(clazz)
  Que.execute("SELECT * FROM que_jobs where job_class = '#{clazz}'")
end

def column_default(table, column_name)
  Que.execute(%{
    SELECT column_name, column_default
    FROM information_schema.columns
    WHERE (table_schema, table_name, column_name) = ('public', '#{table}', '#{column_name}')
  }).first.fetch('column_default')
end

def mock_db_time_now
  # We cannot Timecop freeze the DB clock, so we must override the now lookup.
  allow(Que::Scheduler::Db).to receive(:now).and_return(Time.zone.now)
end
