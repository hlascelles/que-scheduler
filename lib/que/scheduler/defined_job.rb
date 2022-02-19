require "hashie"
require "fugit"

# This is the definition of one scheduleable job in the que-scheduler config yml file.
module Que
  module Scheduler
    class DefinedJob < Hashie::Dash
      include Hashie::Extensions::Dash::PropertyTranslation

      DEFINED_JOB_TYPES = [
        DEFINED_JOB_TYPE_DEFAULT = :default,
        DEFINED_JOB_TYPE_EVERY_EVENT = :every_event,
      ].freeze

      property :name
      property :job_class, transform_with: ->(v) { Object.const_get(v) }
      property :cron, transform_with: ->(v) { Fugit::Cron.parse(v) }
      property :queue
      property :priority
      property :args_array
      property :schedule_type, default: DEFINED_JOB_TYPE_DEFAULT

      class << self
        def create(options)
          defined_job = new(options.compact)
          defined_job.freeze.tap { |dj| dj.validate(options) }
        end
      end

      # Given a "last time", return the next Time the event will occur, or nil if it
      # is after "to".
      def next_run_time(from, to)
        next_time = cron.next_time(from)
        next_run = next_time.to_local_time.in_time_zone(next_time.zone)
        next_run <= to ? next_run : nil
      end

      # Given the last scheduler run time, and this run time, return all
      # the instances that should be enqueued for the job class.
      def calculate_missed_runs(last_run_time, as_time)
        missed_times = []
        last_time = last_run_time
        while (next_run = next_run_time(last_time, as_time))
          missed_times << next_run
          last_time = next_run
        end

        generate_to_enqueue_list(missed_times)
      end

      def validate(options)
        validate_fields_presence(options)
        validate_fields_types(options)
        validate_job_class_related(options)
      end

      private

      # rubocop:disable Style/GuardClause This reads better as a conditional
      def validate_fields_types(options)
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

      def validate_fields_presence(options)
        err_field(:name, options, "name must be present") if name.nil?
        err_field(:job_class, options, "job_class must be present") if job_class.nil?
        # An invalid cron is nil
        err_field(:cron, options, "cron must be present") if cron.nil?
      end

      def validate_job_class_related(options)
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

      def err_field(field, options, reason = "")
        schedule = Que::Scheduler.configuration.schedule_location
        value = options[field]
        raise "Invalid #{field} '#{value}' for '#{name}' in que-scheduler schedule #{schedule}.\n" \
              "#{reason}"
      end

      def generate_to_enqueue_list(missed_times)
        return [] if missed_times.empty?

        options = to_h.slice(:args, :queue, :priority, :job_class).compact

        if schedule_type == DefinedJob::DEFINED_JOB_TYPE_EVERY_EVENT
          missed_times.map do |time_missed|
            ToEnqueue.create(options.merge(args: [time_missed] + args_array))
          end
        else
          [ToEnqueue.create(options.merge(args: args_array))]
        end
      end
    end
  end
end
