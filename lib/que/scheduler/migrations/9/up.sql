CREATE INDEX IF NOT EXISTS que_scheduler_audit_enqueued_scheduler_job_id ON que_scheduler_audit_enqueued USING btree (scheduler_job_id);
