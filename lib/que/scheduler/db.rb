# frozen_string_literal: true

module Que
  module Scheduler
    module Db
      SCHEDULER_COUNT_SQL =
        "SELECT COUNT(*) FROM que_jobs WHERE job_class = '#{Que::Scheduler::SchedulerJob.name}'"
      NOW_SQL = 'SELECT now()'

      class << self
        attr_accessor :transaction_adapter

        def count_schedulers
          Que.execute(SCHEDULER_COUNT_SQL).first.values.first.to_i
        end

        def now
          Que.execute(NOW_SQL).first.values.first
        end

        def transaction
          find_transaction_adapter unless transaction_adapter.present?
          transaction_adapter.transaction do
            yield
          end
        end

        private

        def find_transaction_adapter
          # Favour the real ::ActiveRecord::Base transaction handler if available.
          self.transaction_adapter =
            if defined?(Que::Adapters::ActiveRecord) &&
               Que.adapter.class == Que::Adapters::ActiveRecord
              ::ActiveRecord::Base
            else
              ::Que
            end
        end
      end
    end
  end
end
