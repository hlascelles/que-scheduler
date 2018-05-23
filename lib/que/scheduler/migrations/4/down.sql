ALTER TABLE que_scheduler_audit ALTER COLUMN scheduler_job_id TYPE integer;
ALTER TABLE que_scheduler_audit_enqueued ALTER COLUMN scheduler_job_id TYPE integer;

ALTER TABLE que_scheduler_audit_enqueued DROP COLUMN job_id;
ALTER TABLE que_scheduler_audit_enqueued DROP COLUMN run_at;
