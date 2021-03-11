require "que"
require "sorbet-runtime"
require "sorbet-struct-comparable"

module Que
  module Scheduler
    module ToEnqueue
      # For jobs of type Que::Job
      class QueJobType < T::Struct
        include T::Struct::ActsAsComparable

        const :args, Object, default: []
        const :queue, T.nilable(String)
        const :priority, T.nilable(Integer)
        const :run_at, Time
        const :job_class, T.class_of(::Que::Job)

        def enqueue
          job_settings = {
            queue: queue,
            priority: priority,
            run_at: run_at,
          }.compact
          job =
            if args.is_a?(Hash)
              job_class.enqueue(**args.merge(job_settings))
            else
              job_class.enqueue(*args, **job_settings)
            end

          return nil if job.nil? || !job # nil in Rails < 6.1, false after.

          # Now read the just inserted job back out of the DB to get the actual values that will
          # be used when the job is worked.
          values = Que::Scheduler::VersionSupport.job_attributes(job).slice(
            :args, :queue, :priority, :run_at, :job_class, :job_id
          )
          EnqueuedJobType.new(values)
        end
      end
    end
  end
end
