# typed: true

require "sorbet-runtime"
require "active_support"
require "active_support/time_with_zone"
require_relative "types"

# These are the args that are used for this particular run of the scheduler.
module Que
  module Scheduler
    class SchedulerJobArgs < T::Struct
      extend T::Sig

      const :last_run_time, Types::TIME
      const :job_dictionary, T::Array[String]
      const :as_time, Types::TIME

      sig { params(options: T.nilable(T::Hash[T.any(String, Symbol), Object])).returns(SchedulerJobArgs) }
      def self.build(options)
        now = Que::Scheduler::Db.now
        # First ever run, there is nothing to do but reschedule self to run on the next minute.
        return new(last_run_time: now, job_dictionary: [], as_time: now) if options.nil?

        options = options.symbolize_keys
        last_run_time = String(options.fetch(:last_run_time))
        new(
          last_run_time: T.must(Que::Scheduler::TimeZone.time_zone.parse(last_run_time)),
          job_dictionary: T.cast(options.fetch(:job_dictionary), T::Array[String]),
          as_time: now
        )
      end
    end
  end
end
