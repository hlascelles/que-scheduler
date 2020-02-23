# frozen_string_literal: true

require_relative 'job_type_support'

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
            inserted = ::Que::Scheduler::VersionSupport.execute(
              INSERT_AUDIT_ENQUEUED,
              [scheduler_job_id] + params_from_job(j)
            )
            raise "Cannot save audit row #{scheduler_job_id} #{executed_at} #{j}" if inserted.empty?
          end
        end

        private

        # The params from the job must be retrieved differently depending on whether
        # it is a Que::Job or an ActiveJob.
        def params_from_job(j)
          Que::Scheduler::JobTypeSupport.validate_job_class!(j.class)

          if j.is_a?(::Que::Job)
            attrs = Que::Scheduler::VersionSupport.job_attributes(j)
            attrs.values_at(:job_class, :queue, :priority, :args, :job_id, :run_at)
          elsif j.is_a?(::ActiveJob::Base)
            data = JSON.parse(j.to_json, symbolize_names: true)
            scheduled_at_float = data[:scheduled_at]
            scheduled_at = scheduled_at_float ? Time.zone.at(scheduled_at_float) : nil
            [j.class.to_s] + data.values_at(
              :queue_name, :priority, :arguments, :provider_job_id
            ) + [scheduled_at]
          end
        end
      end
    end
  end
end
