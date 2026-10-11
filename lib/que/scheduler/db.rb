# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "configuration"

module Que
  module Scheduler
    module Db
      SCHEDULER_COUNT_SQL =
        "SELECT COUNT(*) FROM que_jobs WHERE job_class = 'Que::Scheduler::SchedulerJob'"
      NOW_SQL = "SELECT now()"

      class << self
        extend T::Sig

        sig { returns(Integer) }
        def count_schedulers
          T.cast(first_value(SCHEDULER_COUNT_SQL), Integer)
        end

        sig { returns(Time) }
        def now
          T.cast(first_value(NOW_SQL), Time)
        end

        sig { params(sql: String).returns(T.anything) }
        private def first_value(sql)
          Que::Scheduler::DbSupport.execute(sql).fetch(0).values.fetch(0)
        end

        sig do
          type_parameters(:U)
            .params(blk: T.proc.returns(T.type_parameter(:U)))
            .returns(T.type_parameter(:U))
        end
        def transaction(&blk)
          Que::Scheduler.configuration.transaction_adapter.call(&blk)
        end
      end
    end
  end
end
