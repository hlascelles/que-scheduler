# typed: true

require "que"
require "sorbet-runtime"

# This module uses polymorphic dispatch to centralise the differences between supporting Que::Job
# and other job systems.
module Que
  module Scheduler
    class ToEnqueue < Hashie::Dash
      extend T::Sig
      extend T::Helpers

      abstract!

      property :args, required: true, default: []
      property :queue
      property :priority
      property :run_at, required: true
      property :job_class, required: true

      sig { abstract.returns(T.nilable(EnqueuedJobType)) }
      def enqueue; end

      class << self
        extend T::Sig

        sig { params(options: T::Hash[Symbol, T.anything]).returns(ToEnqueue) }
        def create(options)
          T.must(type_from_job_class(T.cast(options.fetch(:job_class), Class))).new(
            options.merge(run_at: options.fetch(:run_at) { Que::Scheduler::Db.now })
          )
        end

        sig { params(job_class: Class).returns(T::Boolean) }
        def valid_job_class?(job_class)
          type_from_job_class(job_class).present?
        end

        sig { returns(T::Boolean) }
        def active_job_defined?
          Object.const_defined?(:ActiveJob)
        end

        sig { returns(T.nilable(Gem::Version)) }
        def active_job_version
          Gem.loaded_specs["activejob"]&.version
        end

        sig { returns(T::Boolean) }
        def active_job_version_supports_queues?
          # Supporting queue name in ActiveJob was removed in Rails 4.2.3
          # https://github.com/rails/rails/pull/19498
          # and readded in Rails 6.0.3
          # https://github.com/rails/rails/pull/38635
          version = ToEnqueue.active_job_version
          !version.nil? && version >= Gem::Version.create("6.0.3")
        end

        sig { params(job_class: Class).returns(T.nilable(T.class_of(ToEnqueue))) }
        private def type_from_job_class(job_class)
          types.each do |type, implementation|
            return implementation if job_class < type
          end
          nil
        end

        sig { returns(T::Hash[Class, T.class_of(ToEnqueue)]) }
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
      sig { override.returns(T.nilable(EnqueuedJobType)) }
      def enqueue
        job_settings = to_h.slice(:queue, :priority, :run_at).compact
        job = Que::Scheduler::DbSupport.enqueue_a_job(
          T.cast(job_class, T.class_of(Que::Job)),
          job_settings,
          args
        )

        return nil if job.nil? || !job # nil in Rails < 6.1, false after.

        # Now read the just inserted job back out of the DB to get the actual values that will
        # be used when the job is worked.
        values = Que::Scheduler::DbSupport.job_attributes(job).slice(
          :args, :queue, :priority, :run_at, :job_class, :job_id
        )
        EnqueuedJobType.new(values)
      end
    end

    # For jobs of type ActiveJob
    class ActiveJobType < ToEnqueue
      sig { override.returns(T.nilable(EnqueuedJobType)) }
      def enqueue
        job = enqueue_active_job

        return nil if job.nil? || !job # nil in Rails < 6.1, false after.

        enqueued_values = calculate_enqueued_values(job)
        EnqueuedJobType.new(enqueued_values)
      end

      sig { params(job: ::ActiveJob::Base).returns(T::Hash[Symbol, T.anything]) }
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

      sig { returns(T.nilable(T.any(::ActiveJob::Base, FalseClass))) }
      def enqueue_active_job
        job_settings = {
          priority: priority,
          wait_until: run_at,
          queue: queue || Que::DEFAULT_QUEUE,
        }.compact

        job_class_set = T.cast(job_class, T.class_of(::ActiveJob::Base)).set(**job_settings)
        job_args = args
        case job_args
        when Hash
          job_class_set.perform_later(**job_args)
        else
          # Sorbet cannot type a splat of a value of unknown size
          T.unsafe(job_class_set).perform_later(*job_args)
        end
      end

      class << self
        extend T::Sig

        # ActiveJob scheduled_at is returned as a float, or a string post Rails 7.1,
        # and we want a Time for consistency
        sig { params(scheduled_at: T.anything).returns(T.nilable(ActiveSupport::TimeWithZone)) }
        def extract_scheduled_at(scheduled_at)
          # rubocop:disable Style/EmptyElse
          case scheduled_at
          when Float
            Que::Scheduler::TimeZone.time_zone.at(scheduled_at)
          when String
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
