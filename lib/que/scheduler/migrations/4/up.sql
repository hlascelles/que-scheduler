ALTER TABLE que_scheduler_audit ALTER COLUMN scheduler_job_id TYPE bigint;
ALTER TABLE que_scheduler_audit_enqueued ALTER COLUMN scheduler_job_id TYPE bigint;

ALTER TABLE que_scheduler_audit_enqueued ADD COLUMN job_id bigint;
ALTER TABLE que_scheduler_audit_enqueued ADD COLUMN run_at timestamptz;

CREATE INDEX que_scheduler_audit_enqueued_job_id ON que_scheduler_audit_enqueued USING btree (job_id);
