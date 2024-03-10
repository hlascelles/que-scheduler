require "que"
require "active_support"
require "active_support/core_ext/time"

require_relative "schedule"
require_relative "enqueueing_calculator"
require_relative "scheduler_job_args"
require_relative "state_checks"
require_relative "to_enqueue"
require_relative "version_support"

# The main job that runs every minute, determining what needs to be enqueued, enqueues the required
# jobs, then re-enqueues itself.
module Que
  module Scheduler
    class SchedulerJob < Que::Job
      SCHEDULER_FREQUENCY = 60

      VersionSupport.set_priority(self, 0)
      VersionSupport.apply_retry_semantics(self)

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

      def enqueue_required_jobs(calculator_result, logs)
        calculator_result.missed_jobs.filter_map do |to_enqueue|
          to_enqueue.enqueue.tap do |enqueued_job|
            check_enqueued_job(to_enqueue, enqueued_job, logs)
          end
        end
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

      private def enqueue_self_again(scheduler_job_args, last_full_execution, job_dictionary,
                                     enqueued_jobs)
        # Log last run...
        job_id = VersionSupport.job_attributes(self).fetch(:job_id)
        Audit.append(job_id, scheduler_job_args.as_time, enqueued_jobs)

        # And rerun...
        next_run_at = scheduler_job_args.as_time.beginning_of_minute + SCHEDULER_FREQUENCY
        enqueued_job = Que::Scheduler::VersionSupport.enqueue_a_job(
          SchedulerJob,
          {
            queue: Que::Scheduler.configuration.que_scheduler_queue,
            run_at: next_run_at,
          },
          {
            last_run_time: last_full_execution.iso8601,
            job_dictionary: job_dictionary,
          }
        )

        # rubocop:disable Style/GuardClause This reads better as a conditional
        unless enqueued_job && VersionSupport.job_attributes(enqueued_job).fetch(:job_id)
          raise "SchedulerJob could not self-schedule. Has `.enqueue` been monkey patched?"
        end
        # rubocop:enable Style/GuardClause
      end
    end
  end
end
