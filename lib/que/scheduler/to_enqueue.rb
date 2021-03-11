require "que"
require "sorbet-runtime"

# This module uses polymorphic dispatch to centralise the differences between supporting Que::Job
# and other job systems.
module Que
  module Scheduler
    module ToEnqueue
      class << self
        def create(options)
          Que::Scheduler::ToEnqueue.type_from_job_class(options.fetch(:job_class)).new(
            options.merge(run_at: Que::Scheduler::Db.now)
          )
        end

        def valid_job_class?(job_class)
          type_from_job_class(job_class).present?
        end

        def active_job_loaded?
          !!active_job_version
        end

        def active_job_version
          Gem.loaded_specs["activejob"]&.version
        end

        def active_job_version_supports_queues?
          # Supporting queue name in ActiveJob was removed in Rails 4.2.3
          # https://github.com/rails/rails/pull/19498
          # and readded in Rails 6.0.3
          # https://github.com/rails/rails/pull/38635
          ToEnqueue.active_job_version && ToEnqueue.active_job_version >=
            Gem::Version.create("6.0.3")
        end

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
              hash[::ActiveJob::Base] = ActiveJobType if ToEnqueue.active_job_loaded?
              hash
            end
        end
      end
    end

    # A value object returned after a job has been enqueued. This is necessary as Que (normal) and
    # ActiveJob return very different objects from the `enqueue` call.
    class EnqueuedJobType < T::Struct
      const :args, Object #  TODO: More accurate?
      const :queue, String
      const :priority, Integer
      const :run_at, Time
      const :job_class, String # TODO make this T.class_of(::Que::Job) or ActiveJob?
      const :job_id, Integer
    end
  end
end

require_relative "to_enqueue/que_job_type"
require_relative "to_enqueue/active_job_type" if Que::Scheduler::ToEnqueue.active_job_loaded?
