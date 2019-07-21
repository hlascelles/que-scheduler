require 'que'

# The purpose of this module is to centralise the differences when supporting both que 0.x and
# 1.x with the same gem.
module Que
  module Scheduler
    module VersionSupport
      class << self
        def set_priority(context, priority)
          context.instance_variable_set('@priority', priority)
        end

        def job_attributes(enqueued_job)
          enqueued_job.attrs.transform_keys(&:to_sym)
        end

        # Between Que 0.x and 1.x the result of `Que.execute` changed keys from strings to symbols.
        # Here we wrap the concept and make sure either way produces symbols
        def execute(str, args = [])
          normalise_array_of_hashes(Que.execute(str, args))
        end

        def default_scheduler_queue
          ''
        end

        def normalise_array_of_hashes(array)
          array.map { |row| row.transform_keys(&:to_sym) }
        end
      end
    end
  end
end
