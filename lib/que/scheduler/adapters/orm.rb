module Que
  module Scheduler
    module Adapters
      module Orm
        class AdapterBase
          SCHEDULER_COUNT_SQL =
            'SELECT COUNT(*) FROM que_jobs WHERE job_class = ' \
            "'#{Que::Scheduler::SchedulerJob.name}'".freeze
          NOW_SQL = 'SELECT now()'.freeze

          def transaction
            transaction_base.transaction do
              yield
            end
          end

          def count_schedulers
            dml(SCHEDULER_COUNT_SQL).first.values.first.to_i
          end

          def now
            Time.zone.parse(dml(NOW_SQL).first.values.first)
          end
        end

        class ActiveRecordAdapter < AdapterBase
          def transaction_base
            ::ActiveRecord::Base
          end

          def dml(sql)
            ::ActiveRecord::Base.connection.execute(sql)
          end

          def ddl(sql)
            dml(sql)
          end
        end

        class SequelAdapter < AdapterBase
          def transaction_base
            ::DB
          end

          def dml(sql)
            ::DB.fetch(sql)
          end

          def ddl(sql)
            ::DB.run(sql)
          end
        end

        class << self
          # The exposed mutator method here allows any future orm adapters to be tested.
          attr_writer :instance

          def instance
            # rubocop:disable Style/PreferredHashMethods
            @instance ||=
              if Gem.loaded_specs.has_key?('activerecord')
                ActiveRecordAdapter.new
              elsif Gem.loaded_specs.has_key?('sequel')
                SequelAdapter.new
              else
                raise 'No known ORM adapter is available for que-scheduler'
              end
            # rubocop:enable Style/PreferredHashMethods
          end
        end
      end
    end
  end
end
