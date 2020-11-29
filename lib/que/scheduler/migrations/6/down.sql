DROP TRIGGER que_scheduler_prevent_job_deletion_trigger ON que_jobs;

DROP FUNCTION que_scheduler_prevent_job_deletion();

DROP FUNCTION que_scheduler_check_job_exists();

DROP INDEX que_scheduler_job_in_que_jobs_unique_index;
