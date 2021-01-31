module SyncJobWorker
  class << self
    # This runs a single job off the job queue. For Que 0.x it will choose using its normal
    # heuristics. For 1.x it will choose the oldest.
    def work_job
      if Que::Scheduler::VersionSupport.zero_major?
        result = ::Que::Job.work
        raise "Job errored: #{result}" unless result[:event] == :job_worked

        result
      else
        job = Que::Scheduler::VersionSupport.execute(
          "SELECT * FROM que_jobs ORDER BY id LIMIT 1"
        ).first
        klass = Que.constantize(job.fetch(:job_class))
        instance = klass.new(job)
        outcome = ::Que.run_job_middleware(job) { instance.tap(&:_run) }

        job_after = Que::Scheduler::VersionSupport.execute(
          "SELECT * FROM que_jobs WHERE id = #{job.fetch(:id)}"
        ).first
        raise "Job errored: #{outcome}" if job_after

        outcome
      end
    end
  end
end
