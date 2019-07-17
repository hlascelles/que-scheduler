# frozen_string_literal: true

require_relative 'config'

module Que
  module Scheduler
    module Db
      SCHEDULER_COUNT_SQL =
        "SELECT COUNT(*) FROM que_jobs WHERE job_class = 'Que::Scheduler::SchedulerJob'"
      NOW_SQL = 'SELECT now()'

      class << self
        def count_schedulers
          Que::Scheduler::VersionSupport.execute(SCHEDULER_COUNT_SQL).first.values.first.to_i
        end

        def now
          Que::Scheduler::VersionSupport.execute(NOW_SQL).first.values.first
        end

        def transaction
          Que::Scheduler.configuration.transaction_adapter.call { yield }
        end
      end
    end
  end
end
