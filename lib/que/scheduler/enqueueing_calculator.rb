require "sorbet-runtime"
require "fugit"

module Que
  module Scheduler
    module EnqueueingCalculator
      class Result < T::Struct
        extend T::Sig
        const :missed_jobs, T::Array[ToEnqueue]
        const :job_dictionary, T::Array[String]
      end

      class << self
        extend T::Sig

        sig {
          params(
            scheduler_config: T::Array[DefinedJob],
            scheduler_job_args: SchedulerJobArgs
          ).returns(Result)
        }
        def parse(scheduler_config, scheduler_job_args)
          job_dictionary = []

          # For each scheduled item:
          # 1) If never seen before, schedule nothing, but add to known list
          # 2) If seen before, calculate what (if anything) needs to be enqueued.
          missed_jobs = scheduler_config.map do |desc|
            job_name = desc.name
            job_dictionary << job_name

            # If we have never seen this job before, we don't want to scheduled any jobs for it.
            # But we have added it to the dictionary, so it will be used to enqueue jobs next time.
            next unless scheduler_job_args.job_dictionary.include?(job_name)

            # This has been seen before. We should check if we have missed any executions.
            desc.calculate_missed_runs(scheduler_job_args.last_run_time, scheduler_job_args.as_time)
          end.flatten.compact

          Result.new(missed_jobs: missed_jobs, job_dictionary: job_dictionary)
        end
      end
    end
  end
end
