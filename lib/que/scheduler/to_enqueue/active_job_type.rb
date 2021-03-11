require "que"
require "sorbet-runtime"
require "sorbet-struct-comparable"




# TODO: Add a Sorbet type check for when this gem is included






module Que
  module Scheduler
    module ToEnqueue
      # For jobs of type ActiveJob
      class ActiveJobType < T::Struct
        include T::Struct::ActsAsComparable

        const :args, Object, default: []
        const :queue, T.nilable(String)
        const :priority, T.nilable(Integer)
        const :run_at, Time
        const :job_class, T.class_of(ActiveJob)

        def enqueue
          job = enqueue_active_job

          return nil if job.nil? || !job # nil in Rails < 6.1, false after.

          enqueued_values = calculate_enqueued_values(job)
          EnqueuedJobType.new(enqueued_values)
        end

        def calculate_enqueued_values(job)
          # Now read the just inserted job back out of the DB to get the actual values that will
          # be used when the job is worked.
          data = JSON.parse(job.to_json, symbolize_names: true)

          # ActiveJob scheduled_at is returned as a float, where we want a Time for consistency
          scheduled_at =
            begin
              scheduled_at_float = data[:scheduled_at]
              # rubocop:disable Style/EmptyElse
              if scheduled_at_float
                Que::Scheduler::TimeZone.time_zone.at(scheduled_at_float)
              else
                nil
              end
              # rubocop:enable Style/EmptyElse
            end

          # Rails didn't support queues for ActiveJob for a while
          used_queue = data[:queue_name] if ToEnqueue.active_job_version_supports_queues?

          # We can't get the priority out of the DB, as the returned `job` doesn't give us access
          # to the underlying ActiveJob that was scheduled. We have no option but to assume
          # it was what we told it to use. If no priority was specified, we must assume it was
          # the Que default, which is 100 t.ly/1jRK5
          assume_used_priority = priority.nil? ? 100 : priority

          {
            args: data.fetch(:arguments),
            queue: used_queue,
            priority: assume_used_priority,
            run_at: scheduled_at,
            job_class: job_class.to_s,
            job_id: data.fetch(:provider_job_id),
          }
        end

        def enqueue_active_job
          job_settings = {
            priority: priority,
            wait_until: run_at,
            queue: queue || Que::Scheduler::VersionSupport.default_scheduler_queue,
          }.compact

          job_class_set = job_class.set(**job_settings)
          if args.is_a?(Hash)
            job_class_set.perform_later(**args)
          else
            job_class_set.perform_later(*args)
          end
        end
      end
    end
  end
end
