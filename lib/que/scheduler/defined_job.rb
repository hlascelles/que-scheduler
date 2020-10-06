# typed: true
require "fugit"
require "sorbet-runtime"
require_relative "sorbet/struct"

# This is the definition of one scheduleable job in the que-scheduler config yml file.
module Que
  module Scheduler
    class DefinedJob < Que::Scheduler::Sorbet::Struct
      # TODO use enums
      DEFINED_JOB_TYPES = [
        DEFINED_JOB_TYPE_DEFAULT = :default,
        DEFINED_JOB_TYPE_EVERY_EVENT = :every_event,
      ].freeze

      const :name, String
      const :job_class, Class
      const :cron, Fugit::Cron
      const :queue, T.nilable(String)
      const :priority, T.nilable(Integer)
      const :args_array, T::Array[Object], default: [] # TODO why default?
      const :schedule_type, Symbol, default: DEFINED_JOB_TYPE_DEFAULT

      def initialize(hash)
        resolved_hash = hash.compact.merge(
          job_class: Object.const_get(hash.fetch(:job_class)),
          cron: Fugit::Cron.parse(hash[:cron])
        )
        validate(hash, resolved_hash)
        super(resolved_hash)
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

      def validate(hash, options)
        validate_fields_presence(hash, options)
        validate_fields_types(hash, options)
        validate_job_class_related(hash, options)
      end

      private

      # rubocop:disable Style/GuardClause This reads better as a conditional
      def validate_fields_types(hash, options)
        unless options[:queue].nil? || options[:queue].is_a?(String)
          err_field(:queue, hash, "queue must be a string")
        end
        unless options[:priority].nil? || options[:priority].is_a?(Integer)
          err_field(:priority, hash, "priority must be an integer")
        end
        unless options[:schedule_type].nil? || DEFINED_JOB_TYPES.include?(options[:schedule_type])
          err_field(:schedule_type, hash, "Not in #{DEFINED_JOB_TYPES}")
        end
      end
      # rubocop:enable Style/GuardClause

      def validate_fields_presence(hash, options)
        err_field(:name, hash, "name must be present") if options[:name].nil?
        err_field(:job_class, hash, "job_class must be present") if options[:job_class].nil?
        # An invalid cron is nil
        err_field(:cron, hash, "cron must be present") if options[:cron].nil?
      end

      def validate_job_class_related(hash, options)
        # Only support known job engines
        determined_job_class = options.fetch(:job_class)
        determined_queue = options[:queue]
        unless Que::Scheduler::ToEnqueue.valid_job_class?(determined_job_class)
          err_field(:job_class, hash, "Job #{determined_job_class} was not a supported job type")
        end

        # queue name is only supported for a subrange of ActiveJob versions. Print this out as a
        # warning.
        if determined_queue &&
           Que::Scheduler::ToEnqueue.active_job_sufficient_version? &&
           determined_job_class < ::ActiveJob::Base &&
           Que::Scheduler::ToEnqueue.active_job_version < Gem::Version.create("6.0.3")
          puts <<-ERR
            WARNING from que-scheduler....
            Between versions 4.2.3 and 6.0.2 (inclusive) Rails did not support setting queue names
            on que jobs with ActiveJob, so que-scheduler cannot support it.
            See removed in Rails 4.2.3
              https://github.com/rails/rails/pull/19498
            And readded in Rails 6.0.3
              https://github.com/rails/rails/pull/38635

            Please remove all "queue" keys from ActiveJobs defined in the que-scheduler.yml config.
            Specifically #{determined_queue} for job #{determined_queue}.
          ERR
        end
      end

      def err_field(field, options, reason = "")
        schedule = Que::Scheduler.configuration.schedule_location
        value = options[field]
        name = options[:name]
        raise "Invalid #{field} '#{value}' for '#{name}' in que-scheduler schedule #{schedule}.\n" \
              "#{reason}"
      end

      def generate_to_enqueue_list(missed_times)
        return [] if missed_times.empty?

        options = {
          queue: queue,
          priority: priority,
          job_class: job_class,
        }.compact

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
