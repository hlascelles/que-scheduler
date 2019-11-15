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
          ::Que::Scheduler::VersionSupport.execute(INSERT_AUDIT, [scheduler_job_id, executed_at])
          enqueued_jobs.each do |j|
            params = []
            if j.is_a?(Que::Job)
              attrs = Que::Scheduler::VersionSupport.job_attributes(j)
              params = attrs.values_at(:job_class, :queue, :priority, :args, :job_id, :run_at)
            elsif j.respond_to?('provider_job_id')
              data = JSON.parse(j.to_json, symbolize_names: true)
              params =
                [j.class.to_s] + data.values_at(:queue_name, :priority, :arguments, :provider_job_id, :scheduled_at)
            end
            inserted = ::Que::Scheduler::VersionSupport.execute(
              INSERT_AUDIT_ENQUEUED,
              [scheduler_job_id] + params
            )
            raise "Cannot save audit row #{scheduler_job_id} #{executed_at} #{j}" if inserted.empty?
          end
        end
      end
    end
  end
end

# {\"arguments\":[]
# \"job_id\":\"773a8d69-f097-44f1-a706-5cd30be0d48f\"
# \"queue_name\":\"default\"
# \"priority\":null
# \"executions\":0
# \"exception_executions\":{}
# \"provider_job_id\":55}" 
