require "sorbet-runtime"
require "active_support"
require "active_support/time_with_zone"

# These are the args that are used for this particular run of the scheduler.
module Que
  module Scheduler
    class SchedulerJobArgs < T::Struct
      extend T::Sig

      const :last_run_time, Time
      const :job_dictionary, T::Array[String]
      const :as_time, Time

      sig { params(options: T.nilable(T::Hash[Symbol, T.untyped])).returns(SchedulerJobArgs) }
      def self.build(options)
        now = Que::Scheduler::Db.now
        parsed_options =
          if options.nil?
            # First ever run, there is nothing to do but reschedule self to run on the next minute.
            {
              last_run_time: now,
              job_dictionary: [],
              as_time: now,
            }
          else
            symbolized_options = options.transform_keys(&:to_sym)
            {
              last_run_time: Que::Scheduler::TimeZone.time_zone.parse(
                symbolized_options.fetch(:last_run_time).to_s
              ),
              job_dictionary: symbolized_options.fetch(:job_dictionary),
              as_time: now,
            }
          end
        new(parsed_options)
      end
    end
  end
end
