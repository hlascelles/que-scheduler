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
