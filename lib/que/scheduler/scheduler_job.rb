# typed: true

require "que"
require "sorbet-runtime"
require "active_support"
require "active_support/core_ext/time"

require_relative "schedule"
require_relative "enqueueing_calculator"
require_relative "scheduler_job_args"
require_relative "state_checks"
require_relative "to_enqueue"
require_relative "db_support"
require_relative "types"

# The main job that runs every minute (or sooner if a job is due), determining what needs to be
# enqueued, enqueues the required jobs, then re-enqueues itself.
module Que
  module Scheduler
    class SchedulerJob < Que::Job
      extend T::Sig

      SCHEDULER_FREQUENCY = 60
      RETRY_PROC = proc { |count|
        # Maximum one hour, otherwise use the default backoff
        count > 7 ? (60 * 60) : ((count**4) + 3)
      }

      self.priority = 0 # Highest
      self.maximum_retry_count = 1 << 128 # Heat death of universe
      self.retry_interval = RETRY_PROC

      sig { params(options: T.nilable(T::Hash[T.any(String, Symbol), Object])).void }
      def run(options = nil)
        Que::Scheduler::Db.transaction do
          Que::Scheduler::StateChecks.check

          scheduler_job_args = SchedulerJobArgs.build(options)
          logs = ["que-scheduler last ran at #{scheduler_job_args.last_run_time}."]
          result = EnqueueingCalculator.parse(Scheduler.schedule.values, scheduler_job_args)
          enqueued_jobs = enqueue_required_jobs(result, logs)
          # Remove this job and schedule self again
          destroy
          enqueue_self_again(
            scheduler_job_args, scheduler_job_args.as_time, result.job_dictionary, enqueued_jobs
          )
          # Only now we're sure nothing errored, log the results
          logs.each { |str| ::Que.log(event: :"que-scheduler", message: str) }
        end
      end

      sig do
        params(
          calculator_result: EnqueueingCalculator::Result,
          logs: T::Array[String]
        ).returns(T::Array[EnqueuedJob])
      end
      def enqueue_required_jobs(calculator_result, logs)
        calculator_result.missed_jobs.filter_map do |to_enqueue|
          to_enqueue.enqueue.tap do |enqueued_job|
            check_enqueued_job(to_enqueue, enqueued_job, logs)
          end
        end
      end

      sig do
        params(
          to_enqueue: ToEnqueue,
          enqueued_job: T.nilable(EnqueuedJob),
          logs: T::Array[String]
        ).void
      end
      private def check_enqueued_job(to_enqueue, enqueued_job, logs)
        logs << if enqueued_job.present?
                  "que-scheduler enqueueing #{enqueued_job.job_class} " \
                    "#{enqueued_job.job_id} with args: #{enqueued_job.args}"
                else
                  # This can happen if a middleware nixes the enqueue call
                  "que-scheduler called enqueue on #{to_enqueue.job_class} " \
                    "but it reported no job was scheduled. Has `enqueue` been overridden?"
                end
      end

      sig do
        params(
          scheduler_job_args: SchedulerJobArgs,
          last_full_execution: Types::TIME,
          job_dictionary: T::Array[String],
          enqueued_jobs: T::Array[EnqueuedJob]
        ).void
      end
      private def enqueue_self_again(scheduler_job_args, last_full_execution, job_dictionary,
                                     enqueued_jobs)
        # Log last run...
        job_id = DbSupport.job_id(self)
        Audit.append(job_id, scheduler_job_args.as_time, enqueued_jobs)

        # And rerun...
        enqueued_job = Que::Scheduler::DbSupport.enqueue_a_job(
          SchedulerJob,
          {
            queue: Que::Scheduler.configuration.que_scheduler_queue,
            run_at: next_run_at(scheduler_job_args.as_time),
          },
          [{ last_run_time: last_full_execution.iso8601, job_dictionary: job_dictionary }]
        )

        return if enqueued_job

        raise "SchedulerJob could not self-schedule. Has `.enqueue` been monkey patched?"
      end

      # Run again at the next minute, or sooner if a job (eg a seconds cron) is due before then
      sig { params(as_time: Types::TIME).returns(Types::TIME) }
      private def next_run_at(as_time)
        next_minute = as_time.beginning_of_minute + SCHEDULER_FREQUENCY
        due_sooner = Scheduler.schedule.values.filter_map { it.next_run_time(as_time, next_minute) }
        T.must([next_minute, *due_sooner].min)
      end
    end
  end
end
