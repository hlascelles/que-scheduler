DROP TABLE que_scheduler_audit_enqueued;
ALTER TABLE que_scheduler_audit DROP CONSTRAINT que_scheduler_audit_pkey;

ALTER TABLE que_scheduler_audit
ADD COLUMN next_run_at      timestamptz,
ADD COLUMN jobs_enqueued    jsonb;

CREATE INDEX index_que_scheduler_audit_on_jobs_enqueued ON que_scheduler_audit USING btree (jobs_enqueued);
