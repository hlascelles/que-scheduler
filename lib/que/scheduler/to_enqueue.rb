require "que"

# This module uses polymorphic dispatch to centralise the differences between supporting Que::Job
# and other job systems.
module Que
  module Scheduler
    class ToEnqueue < Hashie::Dash
      property :args, required: true, default: []
      property :queue
      property :priority
      property :run_at, required: true
      property :job_class, required: true

      class << self
        def create(options)
          type_from_job_class(options.fetch(:job_class)).new(
            options.merge(run_at: Que::Scheduler::Db.now)
          )
        end

        def valid_job_class?(job_class)
          type_from_job_class(job_class).present?
        end

        def active_job_defined?
          Object.const_defined?(:ActiveJob)
        end

        def active_job_version
          Gem.loaded_specs["activejob"]&.version
        end

        def active_job_version_supports_queues?
          # Supporting queue name in ActiveJob was removed in Rails 4.2.3
          # https://github.com/rails/rails/pull/19498
          # and readded in Rails 6.0.3
          # https://github.com/rails/rails/pull/38635
          ToEnqueue.active_job_version && ToEnqueue.active_job_version >=
            Gem::Version.create("6.0.3")
        end

        private def type_from_job_class(job_class)
          types.each do |type, implementation|
            return implementation if job_class < type
          end
          nil
        end

        private def types
          @types ||=
            begin
              hash = {
                ::Que::Job => QueJobType,
              }
              hash[::ActiveJob::Base] = ActiveJobType if ToEnqueue.active_job_defined?
              hash
            end
        end
      end
    end

    # For jobs of type Que::Job
    class QueJobType < ToEnqueue
      def enqueue
        job_settings = to_h.slice(:queue, :priority, :run_at).compact
        job = Que::Scheduler::VersionSupport.enqueue_a_job(
          job_class,
          job_settings,
          args
        )

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

        scheduled_at = self.class.extract_scheduled_at(data[:scheduled_at])

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

      class << self
        # ActiveJob scheduled_at is returned as a float, or a string post Rails 7.1,
        # and we want a Time for consistency
        def extract_scheduled_at(scheduled_at)
          # rubocop:disable Style/EmptyElse
          if scheduled_at.is_a?(Float)
            Que::Scheduler::TimeZone.time_zone.at(scheduled_at)
          elsif scheduled_at.is_a?(String)
            Que::Scheduler::TimeZone.time_zone.parse(scheduled_at)
          else
            nil
          end
          # rubocop:enable Style/EmptyElse
        end
      end
    end

    # A value object returned after a job has been enqueued. This is necessary as Que (normal) and
    # ActiveJob return very different objects from the `enqueue` call.
    class EnqueuedJobType < Hashie::Dash
      property :args
      property :queue
      property :priority
      property :run_at, required: true
      property :job_class, required: true
      property :job_id, required: true
    end
  end
end
