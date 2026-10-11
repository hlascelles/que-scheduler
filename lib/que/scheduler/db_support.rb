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

        sig do
          params(str: String, args: T::Array[T.anything])
            .returns(T::Array[T::Hash[Symbol, T.anything]])
        end
        def execute(str, args = [])
          T.cast(Que.execute(str, args), T::Array[T::Hash[Symbol, T.anything]])
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
      end
    end
  end
end
