require "que"

module Que
  module Scheduler
    module DbSupport
      class << self
        def job_attributes(enqueued_job)
          enqueued_job.que_attrs.to_h.transform_keys(&:to_sym).tap do |hash|
            hash[:job_id] = hash.delete(:id)
          end
        end

        # Between Que versions the result of Que execute changed keys from strings to symbols.
        # Here we wrap the concept and make sure either way produces symbols
        def execute(str, args = [])
          normalise_array_of_hashes(Que.execute(str, args))
        end

        def enqueue_a_job(clazz, job_options = {}, job_args = [])
          if job_args.is_a?(Hash)
            clazz.enqueue(job_args, job_options: job_options)
          else
            clazz.enqueue(*job_args, job_options: job_options)
          end
        end

        def que_version
          @que_version ||= que_version_object.to_s
        end

        private def que_version_object
          @que_version_object ||= Gem.loaded_specs["que"].version
        end

        private def normalise_array_of_hashes(array)
          array.map { |row| row.to_h.transform_keys(&:to_sym) }
        end
      end
    end
  end
end
