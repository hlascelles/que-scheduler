require 'que'

# The purpose of this module is to centralise the differences when supporting both que 0.x and
# 1.x with the same gem.
module Que
  module Scheduler
    module VersionSupport
      class << self
        def set_priority(context, priority)
          if zero_major?
            context.instance_variable_set('@priority', priority)
          else
            context.priority = priority
          end
        end

        def job_attributes(enqueued_job)
          if zero_major?
            enqueued_job.attrs.transform_keys(&:to_sym)
          else
            enqueued_job.que_attrs.transform_keys(&:to_sym).tap do |hash|
              hash[:job_id] = hash.delete(:id)
            end
          end
        end

        # Between Que 0.x and 1.x the result of Que execute changed keys from strings to symbols.
        # Here we wrap the concept and make sure either way produces symbols
        def execute(str, args = [])
          normalise_array_of_hashes(Que.execute(str, args))
        end

        def default_scheduler_queue
          if zero_major?
            ''
          else
            Que::DEFAULT_QUEUE
          end
        end

        def zero_major?
          # This is the only way to handle beta releases too
          @zero_major ||= Gem.loaded_specs['que'].version.to_s.split('.').first.to_i.zero?
        end

        private

        def normalise_array_of_hashes(array)
          array.map { |row| row.transform_keys(&:to_sym) }
        end
      end
    end
  end
end
