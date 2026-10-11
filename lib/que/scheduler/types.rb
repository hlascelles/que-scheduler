# typed: true

require "sorbet-runtime"
require "active_support"
require "active_support/time_with_zone"

module Que
  module Scheduler
    module Types
      # Times come from both Postgres (Time) and the configured zone (TimeWithZone)
      TIME = T.type_alias { T.any(Time, ActiveSupport::TimeWithZone) }
      # A schedule as given in config: job name to its options
      SCHEDULE_CONFIG = T.type_alias do
        T::Hash[T.any(String, Symbol), T::Hash[T.any(String, Symbol), T.anything]]
      end
    end
  end
end
