# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "to_enqueue"
require_relative "types"

module Que
  module Scheduler
    module Audit
      TABLE_NAME = "que_scheduler_audit"
      ENQUEUED_TABLE_NAME = "que_scheduler_audit_enqueued"
      INSERT_AUDIT = %{
        INSERT INTO #{TABLE_NAME} (scheduler_job_id, executed_at)
        VALUES ($1::bigint, $2::timestamptz)
        RETURNING *
      }.freeze
      INSERT_AUDIT_ENQUEUED = %{
        INSERT INTO #{ENQUEUED_TABLE_NAME}
        (scheduler_job_id, job_class, queue, priority, args, job_id, run_at)
        VALUES (
          $1::bigint, $2::varchar, $3::varchar,
          $4::integer, $5::jsonb, $6::bigint, $7::timestamptz
        )
        RETURNING *
      }.freeze

      class << self
        extend T::Sig

        sig do
          params(
            scheduler_job_id: Integer,
            executed_at: Types::TIME,
            enqueued_jobs: T::Array[Que::Scheduler::EnqueuedJob]
          ).void
        end
        def append(scheduler_job_id, executed_at, enqueued_jobs)
          ::Que::Scheduler::DbSupport.execute(INSERT_AUDIT, [scheduler_job_id, executed_at])
          enqueued_jobs.each do |j|
            inserted = ::Que::Scheduler::DbSupport.execute(
              INSERT_AUDIT_ENQUEUED,
              [scheduler_job_id, j.job_class, j.queue, j.priority, j.args, j.job_id, j.run_at]
            )
            next unless inserted.empty?

            raise "Cannot save audit row #{scheduler_job_id} #{executed_at} #{j.inspect}"
          end
        end
      end
    end
  end
end
