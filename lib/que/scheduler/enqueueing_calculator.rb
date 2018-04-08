require 'fugit'

module Que
  module Scheduler
    module EnqueueingCalculator
      class Result < Hashie::Dash
        property :missed_jobs, required: true
        property :schedule_dictionary, required: true
      end

      class << self
        def parse(scheduler_config, scheduler_job_args)
          missed_jobs = {}
          schedule_dictionary = []

          # For each scheduled item:
          # 1) If never seen before, schedule nothing, but add to known list
          # 2) If seen before, calculate what (if anything) needs to be enqueued.
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

          Result.new(missed_jobs: missed_jobs, schedule_dictionary: schedule_dictionary)
        end
      end
    end
  end
end
