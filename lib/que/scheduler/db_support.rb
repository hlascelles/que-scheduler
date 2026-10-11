# typed: true

require "que"
require "sorbet-runtime"

module Que
  module Scheduler
    module DbSupport
      class << self
        extend T::Sig

        sig { params(enqueued_job: Que::Job).returns(T::Hash[Symbol, T.anything]) }
        def job_attributes(enqueued_job)
          enqueued_job.que_attrs.to_h.transform_keys(&:to_sym).tap do |hash|
            hash[:job_id] = hash.delete(:id)
          end
        end

        sig { params(enqueued_job: Que::Job).returns(Integer) }
        def job_id(enqueued_job) = T.cast(job_attributes(enqueued_job).fetch(:job_id), Integer)

        # Between Que versions the result of Que execute changed keys from strings to symbols.
        # Here we wrap the concept and make sure either way produces symbols
        sig do
          params(str: String, args: T::Array[T.anything])
            .returns(T::Array[T::Hash[Symbol, T.anything]])
        end
        def execute(str, args = [])
          normalise_array_of_hashes(Que.execute(str, args))
        end

        sig do
          params(
            clazz: T.class_of(Que::Job),
            job_options: T::Hash[Symbol, T.anything],
            job_args: T.anything
          ).returns(T.nilable(T.any(Que::Job, FalseClass)))
        end
        def enqueue_a_job(clazz, job_options = {}, job_args = [])
          case job_args
          when Hash
            clazz.enqueue(job_args, job_options: job_options)
          else
            # Sorbet cannot type a splat of a value of unknown size
            T.unsafe(clazz).enqueue(*job_args, job_options: job_options)
          end
        end

        sig { returns(String) }
        def que_version
          @que_version ||= que_version_object.to_s
        end

        sig { returns(Gem::Version) }
        private def que_version_object
          @que_version_object ||= T.must(Gem.loaded_specs["que"]).version
        end

        sig { params(array: T::Array[T.anything]).returns(T::Array[T::Hash[Symbol, T.anything]]) }
        private def normalise_array_of_hashes(array)
          array.map { |row| T.cast(row, T::Hash[T.any(String, Symbol), T.anything]).to_h.transform_keys(&:to_sym) }
        end
      end
    end
  end
end
