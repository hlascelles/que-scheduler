require 'hashie'

# These are the args that are used for this particular run of the scheduler.
module Que
  module Scheduler
    class SchedulerJobArgs < Hashie::Dash
      property :last_run_time, required: true
      property :job_dictionary, required: true
      property :as_time, required: true

      def self.build(options)
        parsed =
          if options.nil?
            # First ever run
            {
              last_run_time: Time.zone.now,
              job_dictionary: []
            }
          else
            {
              last_run_time: Time.zone.parse(options.fetch(:last_run_time)),
              job_dictionary: options.fetch(:job_dictionary)
            }
          end
        SchedulerJobArgs.new(parsed.merge(as_time: Time.zone.now))
      end
    end
  end
end
