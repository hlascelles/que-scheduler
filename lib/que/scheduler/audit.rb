# frozen_string_literal: true

module Que
  module Scheduler
    module Audit
      TABLE_NAME = 'que_scheduler_audit'
      ENQUEUED_TABLE_NAME = 'que_scheduler_audit_enqueued'
      INSERT_AUDIT = %{
        INSERT INTO #{TABLE_NAME} (scheduler_job_id, executed_at)
        VALUES ($1::integer, $2::timestamptz)
        RETURNING *
      }
      INSERT_AUDIT_ENQUEUED = %{
        INSERT INTO #{ENQUEUED_TABLE_NAME} (scheduler_job_id, job_class, queue, priority, args)
        VALUES ($1::integer, $2::varchar, $3::varchar, $4::integer, $5::jsonb)
        RETURNING *
      }

      class << self
        def append(job_id, executed_at, result)
          ::Que.execute(INSERT_AUDIT, [job_id, executed_at])
          result.missed_jobs.each do |j|
            inserted = ::Que.execute(
              INSERT_AUDIT_ENQUEUED,
              [
                job_id,
                j.job_class,
                j.queue,
                j.priority,
                j.args
              ]
            )
            raise "Cannot save audit row #{job_id} #{executed_at} #{j}" if inserted.empty?
          end
        end
      end
    end
  end
end
