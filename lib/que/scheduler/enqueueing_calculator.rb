require 'fugit'
require 'backports/2.4.0/hash/compact'

module Que
  module Scheduler
    EnqueueingCalculatorResult = Struct.new(:missed_jobs, :schedule_dictionary)

    class EnqueueingCalculator
      class << self
        def parse(scheduler_config, scheduler_job_args)
          missed_jobs = {}
          schedule_dictionary = []

          # For each scheduled item, we need not schedule a job it if it has no history, as it is
          # new. Otherwise, check how many times we have missed the job since the last run time.
          # If it is "unmissable" then we schedule all of them, with the missed time as an arg,
          # otherwise just schedule it once.
          scheduler_config.each do |desc|
            job_name = desc.name
            schedule_dictionary << job_name

            # If we have never seen this job before, we don't want to scheduled any jobs for it.
            # But we have added it to the dictionary, so it will be used to enqueue jobs next time.
            next unless scheduler_job_args.job_dictionary.include?(job_name)

            # This has been seen before. We should check if we have missed any executions.
            missed = calculate_missed_runs(
              desc, scheduler_job_args.last_run_time, scheduler_job_args.as_time
            )
            missed_jobs[desc.job_class] = missed unless missed.empty?
          end

          EnqueueingCalculatorResult.new(missed_jobs, schedule_dictionary)
        end

        private

        # Given a job description, the last scheduler run time, and this run time, return all
        # the instances that should be enqueued for that job class.
        def calculate_missed_runs(desc, last_run_time, as_time)
          missed_times = []
          last_time = last_run_time
          while (next_run = desc.next_run_time(last_time, as_time))
            missed_times << next_run
            last_time = next_run
          end

          generate_required_jobs_list(desc, missed_times)
        end

        # Given a job description, and the timestamps of the missed events, generate a list of jobs
        # that can be enqueued as an array of arrays of args.
        def generate_required_jobs_list(desc, missed_times)
          jobs_for_class = []

          unless missed_times.empty?
            options = {
              args: desc.args,
              queue: desc.queue,
              priority: desc.priority
            }.compact

            if desc.unmissable
              missed_times.each do |time_missed|
                jobs_for_class << options.merge(args: [time_missed] + (desc.args || []))
              end
            else
              jobs_for_class << options
            end
          end
          jobs_for_class
        end
      end
    end
  end
end
