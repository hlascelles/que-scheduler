ALTER TABLE que_scheduler_audit ALTER COLUMN scheduler_job_id TYPE bigint;
ALTER TABLE que_scheduler_audit_enqueued ALTER COLUMN scheduler_job_id TYPE bigint;
