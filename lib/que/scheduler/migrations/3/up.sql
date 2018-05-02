ALTER TABLE que_scheduler_audit ADD PRIMARY KEY (scheduler_job_id);

CREATE TABLE que_scheduler_audit_enqueued (
  scheduler_job_id integer      NOT NULL REFERENCES que_scheduler_audit (scheduler_job_id),
  job_class        varchar(255) NOT NULL,
  queue            varchar(255),
  priority         integer,
  args             jsonb        NOT NULL
);

CREATE INDEX que_scheduler_audit_enqueued_job_class ON que_scheduler_audit_enqueued USING btree (job_class);
CREATE INDEX que_scheduler_audit_enqueued_args ON que_scheduler_audit_enqueued USING btree (args);

WITH rows AS (SELECT scheduler_job_id, json_array_elements(jobs_enqueued::json) AS enqueued FROM que_scheduler_audit)
INSERT INTO que_scheduler_audit_enqueued(scheduler_job_id, args, job_class)
SELECT scheduler_job_id, (enqueued->>'args')::json AS args, enqueued->>'job_class' AS job_class FROM rows;

ALTER TABLE que_scheduler_audit DROP COLUMN next_run_at;
ALTER TABLE que_scheduler_audit DROP COLUMN jobs_enqueued;
