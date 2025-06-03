# frozen_string_literal: true

module Que
  module Scheduler
    module Migrations
      AUDIT_TABLE_NAME = Que::Scheduler::Audit::TABLE_NAME
      TABLE_COMMENT = %(
        SELECT description FROM pg_class
        LEFT JOIN pg_description ON pg_description.objoid = pg_class.oid
        WHERE relname = '#{AUDIT_TABLE_NAME}'
      ).freeze
      MAX_VERSION = Dir.glob("#{__dir__}/migrations/*").map { |d| File.basename(d) }.map(&:to_i).max

      class << self
        def migrate!(version:)
          # Like que, Do not migrate test DBs.
          return if defined?(Que::Testing)

          Que::Scheduler::Db.transaction do
            current = db_version
            if current < version
              migrate_up(current, version)
            elsif current > version
              migrate_down(current, version)
            end
          end
        end

        # rubocop:disable MagicNumbers/NoReturn
        def db_version
          if audit_table_exists?
            return Que::Scheduler::DbSupport.execute(TABLE_COMMENT).first[:description].to_i
          end

          # At this point we used to be able to tell if it was 0 or 1 by the presence of the
          # que_scheduler job, but that isn't auto enqueued anymore, so we assume it is 0.
          0
        end
        # rubocop:enable MagicNumbers/NoReturn

        def audit_table_exists?
          result = Que::Scheduler::DbSupport.execute(<<-SQL)
            SELECT * FROM information_schema.tables WHERE table_name = '#{AUDIT_TABLE_NAME}';
          SQL
          result.any?
        end

        # This method must be used during initial installation of que-scheduler and if the
        # project migrations are squashed.
        def reenqueue_scheduler_if_missing
          raise <<~MSG unless Que::Migrations.db_version >= 6
            Cannot (re)enqueue the que-scheduler worker unless the Que migrations have been run to at least version 6.
            This probably means you have an old migration that installed que-scheduler, and have then since
            run in another migration that has upgraded que, and are now running the migrations from scratch into a new database.

            To fix this, you should remove the "Que::Scheduler::Migrations.reenqueue_scheduler_if_missing" line from any
            of the older migrations and add it after the last migration that updates Que to at least version 6. eg:

            Que.migrate!(version: 6)
            Que::Scheduler::Migrations.reenqueue_scheduler_if_missing
          MSG
          return unless Que::Scheduler::Db.count_schedulers.zero?

          Que::Scheduler::DbSupport.enqueue_a_job(Que::Scheduler::SchedulerJob)
        end

        private def migrate_up(current, version)
          execute_step(current += 1, :up) until current == version
        end

        private def migrate_down(current, version)
          current += 1
          execute_step(current -= 1, :down) until current == version + 1
        end

        private def execute_step(number, direction)
          sql = File.read("#{__dir__}/migrations/#{number}/#{direction}.sql")
          Que::Scheduler::DbSupport.execute(sql)
          return unless audit_table_exists?

          Que::Scheduler::DbSupport.execute(
            "COMMENT ON TABLE que_scheduler_audit IS '#{direction == :up ? number : number - 1}'"
          )
        end
      end
    end
  end
end
