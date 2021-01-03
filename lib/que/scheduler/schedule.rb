require_relative "configuration"
require_relative "defined_job"

module Que
  module Scheduler
    class Schedule
      class << self
        # The main method for determining the schedule. It has to evaluate the schedule as late as
        # possible (ie just as it is about to be used) as we cannot guarantee we are in a Rails
        # app with initializers. In a future release this may change to "fast fail" in Rails by
        # checking the config up front.
        def schedule
          @schedule ||=
            begin
              configuration = Que::Scheduler.configuration
              if !configuration.schedule.nil?
                # If an explicit schedule as a hash has been defined, use that.
                from_hash(configuration.schedule)
              elsif File.exist?(configuration.schedule_location)
                # If the schedule is defined as a file location, then load it and return it.
                from_file(configuration.schedule_location)
              else
                raise "No que-scheduler config set, or file found " \
                      "at #{configuration.schedule_location}"
              end
            end
        end

        def from_file(location)
          from_yaml(IO.read(location))
        end

        def from_yaml(config)
          config_hash = YAML.safe_load(config)
          from_hash(config_hash)
        end

        def from_hash(config_hash)
          config_hash.map do |name, defined_job_hash|
            [name, hash_item_to_defined_job(name, defined_job_hash)]
          end.to_h
        end

        def hash_item_to_defined_job(name, defined_job_hash_in)
          defined_job_hash = defined_job_hash_in.stringify_keys
          # Que stores arguments as a json array. If the args we have to provide are already an
          # array we can can simply pass them through. If it is a single non-nil value, then we make
          # an array with one item which is that value (this includes if it is a hash). It could
          # also be a single nil value.
          args_array =
            if !defined_job_hash.key?("args")
              # No args were requested
              []
            else
              args = defined_job_hash["args"]
              if args.is_a?(Array)
                # An array of args was requested
                args
              else
                # A single value, a nil, or a hash was requested. que expects this to
                # be enqueued as an array of 1 item
                [args]
              end
            end

          Que::Scheduler::DefinedJob.create(
            name: name,
            job_class: defined_job_hash["class"] || name,
            queue: defined_job_hash["queue"],
            args_array: args_array,
            priority: defined_job_hash["priority"],
            cron: defined_job_hash["cron"],
            schedule_type: defined_job_hash["schedule_type"]&.to_sym
          )
        end
      end
    end

    class << self
      def schedule
        Schedule.schedule
      end
    end
  end
end
