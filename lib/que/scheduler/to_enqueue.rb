require 'que'

# This module uses polymorphic dispatch to centralise the differences between supporting Que::Job
# and other job systems.
module Que
  module Scheduler
    class ToEnqueue < Hashie::Dash
      property :args, required: true, default: []
      property :queue
      property :priority
      property :run_at
      property :job_class, required: true

      class << self
        def create(options)
          type_from_job_class(options.fetch(:job_class)).new(options)
        end

        def valid_job_class?(job_class)
          type_from_job_class(job_class).present?
        end

        def job_id(job)
          type_from_job_class(job.class).job_id(job)
        end

        def params_from_job(job)
          type_from_job_class(job.class).params_from_job(job)
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
        if args.is_a?(Hash)
          job_class.enqueue(**args.merge(job_settings))
        else
          job_class.enqueue(*args, **job_settings)
        end
      end

      class << self
        def job_id(job)
          Que::Scheduler::VersionSupport.job_attributes(job).fetch(:job_id)
        end

        def params_from_job(job)
          attrs = Que::Scheduler::VersionSupport.job_attributes(job)
          attrs.values_at(:job_class, :queue, :priority, :args, :job_id, :run_at)
        end
      end
    end

    # For jobs of type ActiveJob
    class ActiveJobType < ToEnqueue
      def enqueue
        job_settings = to_h.slice(:queue, :priority, :wait_until).compact
        job_class_set = job_class.set(**job_settings)
        if args.is_a?(Hash)
          job_class_set.perform_later(**args)
        else
          job_class_set.perform_later(*args)
        end
      end

      class << self
        def job_id(job)
          job.provider_job_id
        end

        def params_from_job(job)
          data = JSON.parse(job.to_json, symbolize_names: true)
          # ActiveJob scheduled_at is returned as a float, where we want a Time for consistency
          scheduled_at_float = data[:scheduled_at]
          scheduled_at = scheduled_at_float ? Time.zone.at(scheduled_at_float) : nil
          [job.class.to_s] + data.values_at(
            :queue_name, :priority, :arguments, :provider_job_id
          ) + [scheduled_at]
        end
      end
    end
  end
end
