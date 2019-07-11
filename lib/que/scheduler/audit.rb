# frozen_string_literal: true

module Que
  module Scheduler
    module Audit
      TABLE_NAME = 'que_scheduler_audit'
      ENQUEUED_TABLE_NAME = 'que_scheduler_audit_enqueued'
      INSERT_AUDIT = %{
        INSERT INTO #{TABLE_NAME} (scheduler_job_id, executed_at)
        VALUES ($1::bigint, $2::timestamptz)
        RETURNING *
      }
      INSERT_AUDIT_ENQUEUED = %{
        INSERT INTO #{ENQUEUED_TABLE_NAME}
        (scheduler_job_id, job_class, queue, priority, args, job_id, run_at)
        VALUES (
          $1::bigint, $2::varchar, $3::varchar,
          $4::integer, $5::jsonb, $6::bigint, $7::timestamptz
        )
        RETURNING *
      }

      class << self
        def append(scheduler_job_id, executed_at, enqueued_jobs)
          ::Que.execute(INSERT_AUDIT, [scheduler_job_id, executed_at])
          enqueued_jobs.each do |j|
            attrs = Que::Scheduler::VersionSupport.job_attributes(j)
            inserted = ::Que.execute(
              INSERT_AUDIT_ENQUEUED,
              [scheduler_job_id] +
                attrs.values_at(:job_class, :queue, :priority, :args, :job_id, :run_at)
            )
            raise "Cannot save audit row #{scheduler_job_id} #{executed_at} #{j}" if inserted.empty?
          end
        end
      end
    end
  end
end
