require 'que'

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
            # todo test usec
            options.merge(run_at: Que::Scheduler::Db.now.change(usec: 0))
          )
        end

        def valid_job_class?(job_class)
          type_from_job_class(job_class).present?
        end

        def validate_job_class!(job_class)
          raise "Invalid job class #{job_class}" unless valid_job_class?(job_class)
        end

        def active_job_sufficient_version?
          gem_spec = Gem.loaded_specs['activejob']
          # ActiveJob 4.x does not support job_ids correctly
          # https://github.com/rails/rails/pull/20056/files
          gem_spec && gem_spec.version > Gem::Version.create('5')
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
        job_settings = {
          queue_name: queue,
          priority: priority,
          wait_until: run_at
        }.compact

        job_class_set = job_class.set(**job_settings)
        job =
          if args.is_a?(Hash)
            job_class_set.perform_later(**args)
          else
            job_class_set.perform_later(*args)
          end

        return nil if job.nil? || !job # nil in Rails < 6.1, false after.

        # Now read the just inserted job back out of the DB to get the actual values that will
        # be used when the job is worked.
        data = JSON.parse(job.to_json, symbolize_names: true)
        # ActiveJob scheduled_at is returned as a float, where we want a Time for consistency
        scheduled_at_float = data[:scheduled_at]
        scheduled_at = scheduled_at_float ? Time.zone.at(scheduled_at_float) : nil

        EnqueuedJobType.new(
          args: data.fetch(:arguments),
          queue: data.fetch(:queue_name),
          priority: data.fetch(:priority),
          run_at: scheduled_at,
          job_class: job_class.to_s,
          job_id: data.fetch(:provider_job_id)
        )
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
