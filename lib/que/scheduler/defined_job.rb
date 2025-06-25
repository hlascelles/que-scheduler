require "sorbet-runtime"
require "fugit"

# This is the definition of one scheduleable job in the que-scheduler config yml file.
module Que
  module Scheduler
    class DefinedJob < T::Struct
      extend T::Sig

      DEFINED_JOB_TYPES = [
        DEFINED_JOB_TYPE_DEFAULT = :default,
        DEFINED_JOB_TYPE_EVERY_EVENT = :every_event,
      ].freeze

      const :name, String
      const :job_class, Class
      const :cron, Fugit::Cron
      const :queue, T.nilable(String)
      const :priority, T.nilable(Integer)
      const :args_array, T.nilable(Array)
      const :schedule_type, Symbol, default: DEFINED_JOB_TYPE_DEFAULT

      class << self
        extend T::Sig

        sig { params(options: T::Hash[Symbol, T.untyped]).returns(DefinedJob) }
        def create(options)
          transformed_options = options.compact.merge(
            job_class: Object.const_get(options[:job_class].to_s),
            cron: Fugit::Cron.parse(options[:cron].to_s)
          )
          defined_job = new(transformed_options)
          defined_job.validate(options)
          defined_job.freeze
        end
      end

      # Given a "last time", return the next Time the event will occur, or nil if it
      # is after "to".
      sig { params(from: Time, to: Time).returns(T.nilable(Time)) }
      def next_run_time(from, to)
        next_time = cron.next_time(from)
        # Ensure we are comparing timezone-aware times
        next_run = next_time.to_local_time.in_time_zone(next_time.zone)
        next_run <= to ? next_run : nil
      end

      # Given the last scheduler run time, and this run time, return all
      # the instances that should be enqueued for the job class.
      sig { params(last_run_time: Time, as_time: Time).returns(T::Array[ToEnqueue]) }
      def calculate_missed_runs(last_run_time, as_time)
        missed_times = []
        last_time = last_run_time
        while (next_run = next_run_time(last_time, as_time))
          missed_times << next_run
          last_time = next_run
        end

        generate_to_enqueue_list(missed_times)
      end

      sig { params(options: T::Hash[Symbol, T.untyped]).void }
      def validate(options)
        validate_fields_presence(options)
        validate_fields_types(options)
        validate_job_class_related(options)
      end

      # rubocop:disable Style/GuardClause -- This reads better as a conditional
      private def validate_fields_types(options)
        unless queue.nil? || queue.is_a?(String)
          err_field(:queue, options, "queue must be a string")
        end
        unless priority.nil? || priority.is_a?(Integer)
          err_field(:priority, options, "priority must be an integer")
        end
        unless DEFINED_JOB_TYPES.include?(schedule_type)
          err_field(:schedule_type, options, "Not in #{DEFINED_JOB_TYPES}")
        end
      end
      # rubocop:enable Style/GuardClause

      private def validate_fields_presence(options)
        err_field(:name, options, "name must be present") if name.nil?
        err_field(:job_class, options, "job_class must be present") if job_class.nil?
        # An invalid cron is nil
        err_field(:cron, options, "cron must be present") if cron.nil?
      end

      private def validate_job_class_related(options)
        # Only support known job engines
        unless Que::Scheduler::ToEnqueue.valid_job_class?(job_class)
          err_field(:job_class, options, "Job #{job_class} was not a supported job type")
        end

        # queue name is only supported for a subrange of ActiveJob versions. Print this out as a
        # warning.
        if queue &&
           Que::Scheduler::ToEnqueue.active_job_defined? &&
           job_class < ::ActiveJob::Base &&
           Que::Scheduler::ToEnqueue.active_job_version < Gem::Version.create("6.0.3")
          puts <<~ERR
            WARNING from que-scheduler....
            Between versions 4.2.3 and 6.0.2 (inclusive) Rails did not support setting queue names
            on que jobs with ActiveJob, so que-scheduler cannot support it.
            See removed in Rails 4.2.3
              https://github.com/rails/rails/pull/19498
            And readded in Rails 6.0.3
              https://github.com/rails/rails/pull/38635

            Please remove all "queue" keys from ActiveJobs defined in the que-scheduler.yml config.
            Specifically #{queue} for job #{name}.
          ERR
        end
      end

      private def err_field(field, options, reason = "")
        schedule = Que::Scheduler.configuration.schedule_location
        value = options[field]
        raise "Invalid #{field} '#{value}' for '#{name}' in que-scheduler schedule #{schedule}.\n" \
              "#{reason}"
      end

      private def generate_to_enqueue_list(missed_times)
        return [] if missed_times.empty?

        # Convert T::Struct to hash for ToEnqueue.create
        options = {
          job_class: job_class,
          queue: queue,
          priority: priority,
          args: args_array, # Default args
        }.compact

        if schedule_type == DefinedJob::DEFINED_JOB_TYPE_EVERY_EVENT
          missed_times.map do |time_missed|
            # Prepend time_missed to the existing args_array
            current_args = args_array.nil? ? [time_missed] : [time_missed] + args_array
            ToEnqueue.create(options.merge(args: current_args))
          end
        else
          [ToEnqueue.create(options)]
        end
      end
    end
  end
end
