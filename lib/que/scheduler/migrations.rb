# frozen_string_literal: true

module Que
  module Scheduler
    module Migrations
      AUDIT_TABLE_NAME = Que::Scheduler::Audit::TABLE_NAME
      TABLE_COMMENT = %(
        SELECT description FROM pg_class
        LEFT JOIN pg_description ON pg_description.objoid = pg_class.oid
        WHERE relname = '#{AUDIT_TABLE_NAME}'
      )
      MAX_VERSION = Dir.glob("#{__dir__}/migrations/*").map { |d| File.basename(d) }.map(&:to_i).max

      class << self
        def migrate!(version:)
          ::Que.transaction do
            current = db_version
            if current < version
              migrate_up(current, version)
            elsif current > version
              migrate_down(current, version)
            end
          end
        end

        def db_version
          return 0 if Que::Scheduler::Db.count_schedulers.zero?
          return 1 unless ActiveRecord::Base.connection.table_exists?(AUDIT_TABLE_NAME)
          Que.execute(TABLE_COMMENT).first[:description].to_i
        end

        private

        def migrate_up(current, version)
          Que::Scheduler::SchedulerJob.enqueue if current.zero? # Version 1 does not use SQL
          execute_step((current += 1), :up) until current == version
        end

        def migrate_down(current, version)
          current += 1
          execute_step((current -= 1), :down) until current == version + 1
        end

        def execute_step(number, direction)
          Que.execute(IO.read("#{__dir__}/migrations/#{number}/#{direction}.sql"))
          return unless number >= (direction == :up ? 2 : 3)
          Que.execute "COMMENT ON TABLE que_scheduler_audit IS '#{number}'"
        end
      end
    end
  end
end
