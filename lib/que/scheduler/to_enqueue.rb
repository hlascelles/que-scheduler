require "que"
require_relative "sorbet/struct"

# This module uses polymorphic dispatch to centralise the differences between supporting Que::Job
# and other job systems.
module Que
  module Scheduler
    class ToEnqueue < Que::Scheduler::Sorbet::Struct
      const :args, Object, default: [] # TODO review these nilables
      const :queue, T.nilable(String) # TODO review these nilables
      const :priority, T.nilable(Integer) # TODO review these nilables
      const :run_at, Time
      const :job_class, Class

      class << self
        def create(options)
          type_from_job_class(options.fetch(:job_class)).new(
            options.merge(run_at: Que::Scheduler::Db.now)
          )
        end

        def valid_job_class?(job_class)
          type_from_job_class(job_class).present?
        end

        def active_job_version
          Gem.loaded_specs["activejob"]&.version
        end

        def active_job_sufficient_version?
          # ActiveJob 4.x does not support job_ids correctly
          # https://github.com/rails/rails/pull/20056/files
          active_job_version && active_job_version > Gem::Version.create("5")
        end

        def active_job_version_supports_queues?
          # Supporting queue name in ActiveJob was removed in Rails 4.2.3
          # https://github.com/rails/rails/pull/19498
          # and readded in Rails 6.0.3
          # https://github.com/rails/rails/pull/38635
          ToEnqueue.active_job_version && ToEnqueue.active_job_version >=
            Gem::Version.create("6.0.3")
        end

        private

        def type_from_job_class(job_class)
          types.each do |type, implementation|
            return implementation if job_class < type
          end
          nil
        end

        def types
          @types ||=
            begin
              hash = {
                ::Que::Job => QueJobType,
              }
              hash[::ActiveJob::Base] = ActiveJobType if ToEnqueue.active_job_sufficient_version?
              hash
            end
        end
      end
    end

    # For jobs of type Que::Job
    class QueJobType < ToEnqueue
      def enqueue
        job_settings = to_h.slice(:queue, :priority, :run_at).compact
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

    # For jobs of type ActiveJob
    class ActiveJobType < ToEnqueue
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
            scheduled_at_float ? Time.zone.at(scheduled_at_float) : nil
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

    # A value object returned after a job has been enqueued. This is necessary as Que (normal) and
    # ActiveJob return very different objects from the `enqueue` call.
    class EnqueuedJobType < Que::Scheduler::Sorbet::Struct
      const :args, T.nilable(T::Array[Object]) # TODO review these nilables
      const :queue, T.nilable(String) # TODO review these nilables
      const :priority, T.nilable(Integer) # TODO review these nilables
      const :run_at, Time
      const :job_class, String
      const :job_id, Integer
    end
  end
end
