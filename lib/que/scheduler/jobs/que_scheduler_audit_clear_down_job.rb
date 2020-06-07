require "que"

# This job can optionally be scheduled to clear down the que-scheduler audit log if it
# isn't required in the long term.
module Que
  module Scheduler
    module Jobs
      class QueSchedulerAuditClearDownJob < Que::Job
        class << self
          def build_sql(table_name)
            <<-SQL
              WITH deleted AS (
                DELETE FROM #{table_name}
                WHERE scheduler_job_id <= (
                  SELECT scheduler_job_id FROM que_scheduler_audit
                  ORDER BY scheduler_job_id DESC
                  LIMIT 1 OFFSET $1
                ) RETURNING *
              ) SELECT count(*) FROM deleted;
            SQL
          end
        end

        DELETE_AUDIT_ENQUEUED_SQL = build_sql("que_scheduler_audit_enqueued").freeze
        DELETE_AUDIT_SQL = build_sql("que_scheduler_audit").freeze

        # Very low priority
        Que::Scheduler::VersionSupport.set_priority(self, 100)

        def run(options)
          retain_row_count = options.fetch(:retain_row_count)
          Que::Scheduler::Db.transaction do
            # This may delete zero or more than `retain_row_count` depending on if anything was
            # scheduled in each of the past schedule runs
            Que::Scheduler::VersionSupport.execute(DELETE_AUDIT_ENQUEUED_SQL, [retain_row_count])
            # This will delete all but `retain_row_count` oldest rows
            count = Que::Scheduler::VersionSupport.execute(DELETE_AUDIT_SQL, [retain_row_count])
            log = "#{self.class} cleared down #{count.first.fetch(:count)} rows"
            ::Que.log(event: "que-scheduler".to_sym, message: log)
          end
        end
      end
    end
  end
end
