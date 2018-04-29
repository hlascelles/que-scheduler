CREATE TABLE que_scheduler_audit (
  scheduler_job_id integer     NOT NULL,
  executed_at      timestamptz NOT NULL,
  next_run_at      timestamptz NOT NULL,
  jobs_enqueued    jsonb       NOT NULL
);

CREATE UNIQUE INDEX index_que_scheduler_audit_on_scheduler_job_id ON que_scheduler_audit USING btree (scheduler_job_id);
CREATE INDEX index_que_scheduler_audit_on_jobs_enqueued ON que_scheduler_audit USING btree (jobs_enqueued);
