# typed: true

require "sorbet-runtime"

module Que
  module Scheduler
    # How a job catches up on runs missed while the scheduler was not running.
    class ScheduleType < T::Enum
      enums do
        # Enqueue only the most recent missed run
        DEFAULT = new("default")
        # Enqueue every missed run, passing each its scheduled time as the first arg
        EVERY_EVENT = new("every_event")
      end
    end
  end
end
