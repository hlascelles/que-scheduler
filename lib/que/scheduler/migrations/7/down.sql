CREATE OR REPLACE FUNCTION que_scheduler_prevent_job_deletion() RETURNS TRIGGER AS
$BODY$
DECLARE
BEGIN
    IF OLD.job_class = 'Que::Scheduler::SchedulerJob' THEN
        IF NOT que_scheduler_check_job_exists() THEN
            raise exception 'Deletion of que_scheduler job % prevented. Deleting the que_scheduler job is almost certainly a mistake.', OLD.job_id;
        END IF;
    END IF;
    RETURN OLD;
END;
$BODY$
LANGUAGE 'plpgsql';
