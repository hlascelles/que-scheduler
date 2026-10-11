# typed: true

require "json"
require "que"
require "sorbet-runtime"
require_relative "db_support"
require_relative "time_zone"

# Centralises the differences between enqueueing a Que::Job and an ActiveJob.
module Que
  module Scheduler
    module JobAdapter
      extend T::Sig
      extend T::Helpers

      interface!

      sig { abstract.params(to_enqueue: ToEnqueue).returns(T.nilable(EnqueuedJob)) }
      def enqueue(to_enqueue); end
    end

    class QueAdapter
      extend T::Sig
      include JobAdapter

      sig { override.params(to_enqueue: ToEnqueue).returns(T.nilable(EnqueuedJob)) }
      def enqueue(to_enqueue)
        job_options = {
          queue: to_enqueue.queue,
          priority: to_enqueue.priority,
          run_at: to_enqueue.run_at,
        }.compact
        job = DbSupport.enqueue_a_job(
          T.cast(to_enqueue.job_class, T.class_of(Que::Job)), job_options, to_enqueue.args
        )
        read_back(job) if job
      end

      # Read the job back to get the values that will be used when it is worked
      sig { params(job: Que::Job).returns(EnqueuedJob) }
      private def read_back(job)
        attrs = DbSupport.job_attributes(job)
        EnqueuedJob.new(
          job_class: T.cast(attrs.fetch(:job_class), String),
          args: T.cast(attrs.fetch(:args), T::Array[T.anything]),
          queue: T.cast(attrs.fetch(:queue), String),
          priority: T.cast(attrs.fetch(:priority), Integer),
          run_at: T.cast(attrs.fetch(:run_at), Time),
          job_id: DbSupport.job_id(job)
        )
      end
    end

    class ActiveJobAdapter
      extend T::Sig
      include JobAdapter

      # Que's column default, which ActiveJob does not let us read back. t.ly/1jRK5
      QUE_DEFAULT_PRIORITY = 100

      sig { override.params(to_enqueue: ToEnqueue).returns(T.nilable(EnqueuedJob)) }
      def enqueue(to_enqueue)
        job_class = T.cast(to_enqueue.job_class, T.class_of(::ActiveJob::Base))
        job_settings = {
          priority: to_enqueue.priority,
          wait_until: to_enqueue.run_at,
          queue: to_enqueue.queue || Que::DEFAULT_QUEUE,
        }.compact
        # Sorbet cannot type a splat of an array of unknown size
        job = T.unsafe(job_class.set(**job_settings)).perform_later(*to_enqueue.args)
        read_back(job, to_enqueue) if job
      end

      sig { params(job: ::ActiveJob::Base, to_enqueue: ToEnqueue).returns(EnqueuedJob) }
      private def read_back(job, to_enqueue)
        data = JSON.parse(job.to_json, symbolize_names: true)
        EnqueuedJob.new(
          job_class: to_enqueue.job_class.to_s,
          args: data.fetch(:arguments),
          queue: data.fetch(:queue_name),
          # The enqueued job does not expose its priority, so assume it is what we asked for
          priority: to_enqueue.priority || QUE_DEFAULT_PRIORITY,
          run_at: self.class.extract_scheduled_at(data.fetch(:scheduled_at)),
          job_id: data.fetch(:provider_job_id)
        )
      end

      # ActiveJob serialises scheduled_at as an ISO 8601 string; we want a Time
      sig { params(scheduled_at: String).returns(ActiveSupport::TimeWithZone) }
      def self.extract_scheduled_at(scheduled_at)
        T.must(Que::Scheduler::TimeZone.time_zone.parse(scheduled_at))
      end
    end

    module JobAdapters
      QUE_ADAPTER = QueAdapter.new
      ACTIVE_JOB_ADAPTER = ActiveJobAdapter.new

      class << self
        extend T::Sig

        sig { returns(T::Boolean) }
        def active_job_defined? = Object.const_defined?(:ActiveJob)

        sig { params(job_class: Class).returns(T::Boolean) }
        def supports?(job_class) = !!find(job_class)

        sig { params(job_class: Class).returns(JobAdapter) }
        def adapter_for(job_class) = T.must(find(job_class))

        sig { params(job_class: Class).returns(T.nilable(JobAdapter)) }
        private def find(job_class)
          if job_class < ::Que::Job
            QUE_ADAPTER
          elsif active_job_defined? && job_class < ::ActiveJob::Base
            ACTIVE_JOB_ADAPTER
          end
        end
      end
    end
  end
end
