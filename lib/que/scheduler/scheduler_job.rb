require 'que'

require_relative 'schedule'
require_relative 'enqueueing_calculator'
require_relative 'scheduler_job_args'
require_relative 'state_checks'
require_relative 'version_support'

# The main job that runs every minute, determining what needs to be enqueued, enqueues the required
# jobs, then re-enqueues itself.
module Que
  module Scheduler
    class SchedulerJob < Que::Job
      SCHEDULER_FREQUENCY = 60

      Que::Scheduler::VersionSupport.set_priority(self, 0)
      Que::Scheduler::VersionSupport.apply_retry_semantics(self)

      def run(options = nil)
        Que::Scheduler::Db.transaction do
          Que::Scheduler::StateChecks.check

          scheduler_job_args = SchedulerJobArgs.build(options)
          logs = ["que-scheduler last ran at #{scheduler_job_args.last_run_time}."]

          result = EnqueueingCalculator.parse(Scheduler.schedule.values, scheduler_job_args)
          enqueued_jobs = enqueue_required_jobs(result, logs)
          enqueue_self_again(
            scheduler_job_args, scheduler_job_args.as_time, result.job_dictionary, enqueued_jobs
          )

          # Only now we're sure nothing errored, log the results
          logs.each { |str| ::Que.log(event: 'que-scheduler'.to_sym, message: str) }
          destroy
        end
      end

      def enqueue_required_jobs(result, logs)
        result.missed_jobs.map do |to_enqueue|
          job_class = to_enqueue.job_class
          args = to_enqueue.args
          remaining_hash = to_enqueue.except(:job_class, :args)
          enqueued_job =
            if args.is_a?(Hash)
              enqueue(job_class, args.merge(remaining_hash))
            else
              enqueue(job_class, *args, remaining_hash)
            end
          check_enqueued_job(enqueued_job, job_class, args, logs)
        end.compact
      end

      private

      def enqueue(*args, **kwargs)
        job_class = args.shift
        if job_class.respond_to?(:enqueue)
          return job_class.enqueue(*args, **kwargs)
        elsif job_class.respond_to?(:perform_later)
          return job_class.perform_later(*args, **kwargs)
        end
      end

      def check_enqueued_job(enqueued_job, job_class, args, logs)
        job_id = nil
        if enqueued_job.is_a?(Que::Job)
          job_id = Que::Scheduler::VersionSupport.job_attributes(enqueued_job).fetch(:job_id)
        elsif enqueued_job.respond_to?('provider_job_id')
          job_id = enqueued_job.provider_job_id
        else
          # This can happen if a middleware nixes the enqueue call
          logs << "que-scheduler called enqueue on #{job_class} but did not receive a #{Que::Job}"
          return nil
        end
        logs << "que-scheduler enqueueing #{job_class} #{job_id} with args: #{args}"
        return enqueued_job
      end

      def enqueue_self_again(scheduler_job_args, last_full_execution, job_dictionary, enqueued_jobs)
        # Log last run...
        job_id = Que::Scheduler::VersionSupport.job_attributes(self).fetch(:job_id)
        Audit.append(job_id, scheduler_job_args.as_time, enqueued_jobs)

        # And rerun...
        next_run_at = scheduler_job_args.as_time.beginning_of_minute + SCHEDULER_FREQUENCY
        enqueued_job = SchedulerJob.enqueue(
          queue: Que::Scheduler.configuration.que_scheduler_queue,
          last_run_time: last_full_execution.iso8601,
          job_dictionary: job_dictionary,
          run_at: next_run_at
        )

        # rubocop:disable Style/GuardClause This reads better as a conditional
        unless check_enqueued_job(enqueued_job, SchedulerJob, {}, [])
          raise 'SchedulerJob could not self-schedule. Has `.enqueue` been monkey patched?'
        end
        # rubocop:enable Style/GuardClause
      end
    end
  end
end
