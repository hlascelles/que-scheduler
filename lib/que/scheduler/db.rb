# frozen_string_literal: true

module Que
  module Scheduler
    module Db
      SCHEDULER_COUNT_SQL =
        "SELECT COUNT(*) FROM que_jobs WHERE job_class = '#{Que::Scheduler::SchedulerJob.name}'"
      NOW_SQL = 'SELECT now()'

      class << self
        def count_schedulers
          Que.execute(SCHEDULER_COUNT_SQL).first.values.first.to_i
        end

        def now
          Que.execute(NOW_SQL).first.values.first
        end

        def transaction
          Que.adapter.checkout do
            use = use_active_record_transaction_adapter ? ::ActiveRecord::Base : ::Que
            use.transaction do
              yield
            end
          end
        end

        private

        def use_active_record_transaction_adapter
          # Favour the real ::ActiveRecord::Base transaction handler if available.
          defined?(Que::Adapters::ActiveRecord) &&
             Que.adapter.class == Que::Adapters::ActiveRecord
        end
      end
    end
  end
end
