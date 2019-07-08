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
      end
    end
  end
end
