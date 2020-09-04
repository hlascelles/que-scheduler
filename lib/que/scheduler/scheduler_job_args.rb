require_relative "sorbet/struct"
require "active_support"
require "active_support/time_with_zone"

# These are the args that are used for this particular run of the scheduler.
module Que
  module Scheduler
    class SchedulerJobArgs < Que::Scheduler::Sorbet::Struct
      const :last_run_time, Time
      const :job_dictionary, T::Array[String]
      const :as_time, Time

      def self.build(options)
        now = Que::Scheduler::Db.now
        parsed =
          if options.nil?
            # First ever run, there is nothing to do but reschedule self to run on the next minute.
            {
              last_run_time: now,
              job_dictionary: [],
            }
          else
            options = options.symbolize_keys
            {
              last_run_time: Time.zone.parse(options.fetch(:last_run_time)),
              job_dictionary: options.fetch(:job_dictionary),
            }
          end
        SchedulerJobArgs.new(parsed.merge(as_time: now))
      end
    end
  end
end
