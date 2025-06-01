# frozen_string_literal: true

require_relative "configuration"

module Que
  module Scheduler
    module Db
      SCHEDULER_COUNT_SQL =
        "SELECT COUNT(*) FROM que_jobs WHERE job_class = 'Que::Scheduler::SchedulerJob'"
      NOW_SQL = "SELECT now()"

      class << self
        def count_schedulers
          Que::Scheduler::DbSupport.execute(SCHEDULER_COUNT_SQL).first.values.first.to_i
        end

        def now
          Que::Scheduler::DbSupport.execute(NOW_SQL).first.values.first
        end

        # rubocop:disable Style/ExplicitBlockArgument
        def transaction
          Que::Scheduler.configuration.transaction_adapter.call { yield }
        end
        # rubocop:enable Style/ExplicitBlockArgument
      end
    end
  end
end
