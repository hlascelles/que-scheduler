require 'que'

# The purpose of this module is to centralise the differences when supporting Que::Job and
# ActiveJob.
module Que
  module Scheduler
    module JobTypeSupport
      class << self
        def valid_job_class?(job_class)
          job_class < ::Que::Job || (active_job_loaded? && job_class < ::ActiveJob::Base)
        end

        def job_id(job)
          validate_job_class!(job.class)

          if job.is_a?(Que::Job)
            Que::Scheduler::VersionSupport.job_attributes(job).fetch(:job_id)
          elsif active_job_loaded? && job.is_a?(::ActiveJob::Base)
            job.provider_job_id
          end
        end

        # rubocop:disable Style/GuardClause This reads better as a conditional
        def enqueue(*args, **kwargs)
          job_class = args.shift
          validate_job_class!(job_class)

          if job_class < ::Que::Job
            job_class.enqueue(*args, **kwargs)
          elsif job_class < ::ActiveJob::Base
            job_class.perform_later(*args, **kwargs)
          end
        end
        # rubocop:enable Style/GuardClause

        def params_from_job(j)
          validate_job_class!(j.class)

          if j.is_a?(::Que::Job)
            attrs = Que::Scheduler::VersionSupport.job_attributes(j)
            attrs.values_at(:job_class, :queue, :priority, :args, :job_id, :run_at)
          elsif j.is_a?(::ActiveJob::Base)
            data = JSON.parse(j.to_json, symbolize_names: true)
            scheduled_at_float = data[:scheduled_at]
            scheduled_at = scheduled_at_float ? Time.zone.at(scheduled_at_float) : nil
            [j.class.to_s] + data.values_at(
              :queue_name, :priority, :arguments, :provider_job_id
            ) + [scheduled_at]
          end
        end

        def validate_job_class!(job_class)
          raise "Invalid job class #{job_class}" unless valid_job_class?(job_class)
        end

        private def active_job_loaded?
          @active_job_loaded ||= Gem.loaded_specs.key?('activejob')
        end
      end
    end
  end
end
