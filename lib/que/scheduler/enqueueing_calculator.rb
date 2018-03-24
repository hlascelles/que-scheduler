module Que
  module Scheduler
    class EnqueueingCalculator
      Result = Struct.new(:missed_jobs, :schedule_dictionary)

      class << self
        def parse(scheduler_config, scheduler_job_args)
          missed_jobs = {}
          schedule_dictionary = []

          # For each scheduled item, we need not schedule a job it if it has no history, as it is
          # new. Otherwise, check how many times we have missed the job since the last run time.
          # If it is "every_event" then we schedule all of them, with the missed time as an arg,
          # otherwise just schedule it once.
          scheduler_config.each do |desc|
            job_name = desc.name
            schedule_dictionary << job_name

            # If we have never seen this job before, we don't want to scheduled any jobs for it.
            # But we have added it to the dictionary, so it will be used to enqueue jobs next time.
            next unless scheduler_job_args.job_dictionary.include?(job_name)

            # This has been seen before. We should check if we have missed any executions.
            missed = desc.calculate_missed_runs(
              scheduler_job_args.last_run_time, scheduler_job_args.as_time
            )
            missed_jobs[desc.job_class] = missed unless missed.empty?
          end

          Result.new(missed_jobs, schedule_dictionary)
        end
      end
    end
  end
end
