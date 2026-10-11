# typed: true

require "sorbet-runtime"
require "fugit"
require_relative "schedule_type"
require_relative "to_enqueue"
require_relative "types"

# This is the definition of one scheduleable job in the que-scheduler config yml file.
module Que
  module Scheduler
    class DefinedJob < T::Struct
      extend T::Sig

      const :name, String
      const :job_class, Class
      const :cron, Fugit::Cron
      # nil means use the job class's own queue and priority
      const :queue, T.nilable(String)
      const :priority, T.nilable(Integer)
      const :args_array, T::Array[T.anything], default: []
      const :schedule_type, ScheduleType, default: ScheduleType::DEFAULT

      # Given a "last time", return the next Time the event will occur, or nil if it
      # is after "to".
      sig { params(from: Types::TIME, to: Types::TIME).returns(T.nilable(ActiveSupport::TimeWithZone)) }
      def next_run_time(from, to)
        next_time = cron.next_time(from)
        next_run = next_time.to_local_time.in_time_zone(next_time.zone)
        next_run <= to ? next_run : nil
      end

      # Given the last scheduler run time, and this run time, return all
      # the instances that should be enqueued for the job class.
      sig { params(last_run_time: Types::TIME, as_time: Types::TIME).returns(T::Array[ToEnqueue]) }
      def calculate_missed_runs(last_run_time, as_time)
        missed_times = T.let([], T::Array[ActiveSupport::TimeWithZone])
        last_time = T.let(last_run_time, Types::TIME)
        while (next_run = next_run_time(last_time, as_time))
          missed_times << next_run
          last_time = next_run
        end

        generate_to_enqueue_list(missed_times)
      end

      sig { params(missed_times: T::Array[ActiveSupport::TimeWithZone]).returns(T::Array[ToEnqueue]) }
      private def generate_to_enqueue_list(missed_times)
        last_missed_time = missed_times.last
        return [] if last_missed_time.nil?

        if schedule_type == ScheduleType::EVERY_EVENT
          missed_times.map { to_enqueue(it, [it.iso8601] + args_array) }
        else
          [to_enqueue(last_missed_time, args_array)]
        end
      end

      sig { params(run_at: ActiveSupport::TimeWithZone, args: T::Array[T.anything]).returns(ToEnqueue) }
      private def to_enqueue(run_at, args)
        ToEnqueue.new(
          job_class: job_class, args: args, queue: queue, priority: priority, run_at: run_at
        )
      end
    end
  end
end
