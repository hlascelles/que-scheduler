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

        def db_version
          if audit_table_exists?
            return Que::Scheduler::DbSupport.execute(TABLE_COMMENT).first[:description].to_i
          end

          Que::Scheduler::Db.count_schedulers.zero? ? 0 : 1
        end

        def audit_table_exists?
          result = Que::Scheduler::DbSupport.execute(<<-SQL)
            SELECT * FROM information_schema.tables WHERE table_name = '#{AUDIT_TABLE_NAME}';
          SQL
          result.any?
        end

        # This method is only intended for use in squashed migrations
        def reenqueue_scheduler_if_missing
          return unless Que::Scheduler::Db.count_schedulers.zero?

          Que::Scheduler::DbSupport.enqueue_a_job(Que::Scheduler::SchedulerJob)
        end

        private def migrate_up(current, version)
          if current.zero? # Version 1 does not use SQL
            Que::Scheduler::DbSupport.enqueue_a_job(Que::Scheduler::SchedulerJob)
          end
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
