-- Ensure there is no more than one scheduler
CREATE UNIQUE INDEX que_scheduler_job_in_que_jobs_unique_index ON que_jobs(job_class)
WHERE job_class = 'Que::Scheduler::SchedulerJob';

-- Ensure there is at least one scheduler
CREATE OR REPLACE FUNCTION que_scheduler_check_job_exists() RETURNS bool AS $$
SELECT EXISTS(SELECT * FROM que_jobs WHERE job_class = 'Que::Scheduler::SchedulerJob');
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION que_scheduler_prevent_job_deletion() RETURNS TRIGGER AS
$BODY$
DECLARE
BEGIN
    IF OLD.job_class = 'Que::Scheduler::SchedulerJob' THEN
        IF NOT que_scheduler_check_job_exists() THEN
            raise exception 'Deletion of que_scheduler job prevented. Deleting the que_scheduler job is almost certainly a mistake.';
        END IF;
    END IF;
    RETURN OLD;
END;
$BODY$
LANGUAGE 'plpgsql';

CREATE CONSTRAINT TRIGGER que_scheduler_prevent_job_deletion_trigger AFTER UPDATE OR DELETE ON que_jobs
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE PROCEDURE que_scheduler_prevent_job_deletion();
