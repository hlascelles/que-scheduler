# frozen_string_literal: true

module Que
  module Scheduler
    module Audit
      TABLE_NAME = 'que_scheduler_audit'
      INSERT_AUDIT = %{
        INSERT INTO #{TABLE_NAME} (scheduler_job_id, jobs_enqueued, executed_at, next_run_at)
        VALUES ($1::integer, $2::jsonb, $3::timestamptz, $4::timestamptz)
        RETURNING *
      }

      class << self
        def append(job_id, executed_at, result, next_run_at)
          json = result.missed_jobs.map { |j| j.to_h.merge(job_class: j.job_class.to_s) }.to_json
          inserted = ::Que.execute(
            INSERT_AUDIT, [job_id, json, executed_at, next_run_at]
          )
          raise "Cannot save audit row #{job_id} #{executed_at}" if inserted.empty?
        end
      end
    end
  end
end
