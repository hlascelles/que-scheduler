require "sorbet-runtime"
require "que"

# This module uses polymorphic dispatch to centralise the differences between supporting Que::Job
# and other job systems.
module Que
  module Scheduler
    class ToEnqueue < T::Struct
      extend T::Sig

      const :args, T.any(T::Array[T.untyped], T::Hash[Symbol, T.untyped]), default: []
      const :queue, T.nilable(String)
      const :priority, T.nilable(Integer)
      const :run_at, Time
      const :job_class, Class

      class << self
        extend T::Sig

        sig { params(options: T::Hash[Symbol, T.untyped]).returns(ToEnqueue) }
        def create(options)
          # Ensure options keys are symbols for T::Struct
          symbolized_options = options.transform_keys(&:to_sym)
          job_class_val = symbolized_options.fetch(:job_class)
          # Sorbet needs the exact type for the constructor
          klass = type_from_job_class(job_class_val)
          raise "Unknown job_class type #{job_class_val}" if klass.nil?

          klass.new(
            symbolized_options.merge(run_at: Que::Scheduler::Db.now)
          )
        end

        sig { params(job_class: Class).returns(T::Boolean) }
        def valid_job_class?(job_class)
          !type_from_job_class(job_class).nil?
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
          active_job_version && active_job_version >= Gem::Version.create("6.0.3")
        end

        private

        sig { params(job_class: Class).returns(T.nilable(T.class_of(ToEnqueue))) }
        def type_from_job_class(job_class)
          types.each do |type, implementation|
            return implementation if job_class <= type
          end
          nil
        end

        sig { returns(T::Hash[Class, T.class_of(ToEnqueue)]) }
        def types
          @types ||=
            begin
              hash = {
                ::Que::Job => QueJobType,
              }
              hash[::ActiveJob::Base] = ActiveJobType if active_job_defined?
              T.let(hash, T::Hash[Class, T.class_of(ToEnqueue)])
            end
        end
      end
    end

    # For jobs of type Que::Job
    class QueJobType < ToEnqueue
      extend T::Sig

      sig { returns(T.nilable(EnqueuedJobType)) }
      def enqueue
        job_settings = {
          queue: queue,
          priority: priority,
          run_at: run_at,
        }.compact
        # Ensure args is an Array for Que::Job
        job_args = args.is_a?(Hash) ? [args] : Array(args)
        db_job = Que::Scheduler::DbSupport.enqueue_a_job(
          job_class,
          job_settings,
          job_args
        )

        return nil if db_job.nil? || !db_job # nil in Rails < 6.1, false after.

        # Now read the just inserted job back out of the DB to get the actual values that will
        # be used when the job is worked.
        values = Que::Scheduler::DbSupport.job_attributes(db_job).slice(
          :args, :queue, :priority, :run_at, :job_class, :job_id
        ).transform_keys(&:to_sym) # Ensure keys are symbols for T::Struct
        EnqueuedJobType.new(values)
      end
    end

    # For jobs of type ActiveJob
    class ActiveJobType < ToEnqueue
      extend T::Sig

      sig { returns(T.nilable(EnqueuedJobType)) }
      def enqueue
        job = enqueue_active_job

        return nil if job.nil? || !job # nil in Rails < 6.1, false after.

        enqueued_values = calculate_enqueued_values(job)
        EnqueuedJobType.new(enqueued_values)
      end

      sig { params(job: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
      def calculate_enqueued_values(job)
        # Now read the just inserted job back out of the DB to get the actual values that will
        # be used when the job is worked.
        data = JSON.parse(job.to_json, symbolize_names: true)

        scheduled_at = self.class.extract_scheduled_at(T.let(data[:scheduled_at], T.untyped))

        # Rails didn't support queues for ActiveJob for a while
        used_queue = data[:queue_name] if self.class.active_job_version_supports_queues?

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
          job_class: job_class.to_s, # job_class in EnqueuedJobType is a String
          job_id: data.fetch(:provider_job_id),
        }
      end

      sig { returns(T.untyped) } # Returns an ActiveJob::Base instance or similar
      def enqueue_active_job
        job_settings = {
          priority: priority,
          wait_until: run_at,
          queue: queue || Que::DEFAULT_QUEUE,
        }.compact

        job_class_set = job_class.set(**job_settings)
        current_args = args # To satisfy Sorbet's ExperimentalPass
        if current_args.is_a?(Hash)
          job_class_set.perform_later(**current_args)
        else
          job_class_set.perform_later(*current_args)
        end
      end

      class << self
        extend T::Sig
        # ActiveJob scheduled_at is returned as a float, or a string post Rails 7.1,
        # and we want a Time for consistency
        sig { params(scheduled_at: T.untyped).returns(T.nilable(Time)) }
        def extract_scheduled_at(scheduled_at)
          # rubocop:disable Style/EmptyElse
          if scheduled_at.is_a?(Float)
            Que::Scheduler::TimeZone.time_zone.at(scheduled_at)
          elsif scheduled_at.is_a?(String)
            Que::Scheduler::TimeZone.time_zone.parse(scheduled_at)
          else
            # Sorbet needs an explicit return type if the block could be empty
            T.let(nil, T.nilable(Time))
          end
          # rubocop:enable Style/EmptyElse
        end
      end
    end

    # A value object returned after a job has been enqueued. This is necessary as Que (normal) and
    # ActiveJob return very different objects from the `enqueue` call.
    class EnqueuedJobType < T::Struct
      extend T::Sig
      const :args, T.untyped # Can be Array or Hash
      const :queue, T.nilable(String)
      const :priority, T.nilable(Integer)
      const :run_at, Time
      const :job_class, String # Stored as string from ActiveJob, keep consistent
      const :job_id, T.any(Integer, String) # Que uses Integer, AJ uses String
    end
  end
end
