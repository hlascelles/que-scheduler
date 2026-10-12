# typed: true

require "sorbet-runtime"
require_relative "configuration"
require_relative "defined_job"
require_relative "defined_job_parser"
require_relative "types"

module Que
  module Scheduler
    class Schedule
      class << self
        extend T::Sig

        # The main method for determining the schedule. It has to evaluate the schedule as late as
        # possible (ie just as it is about to be used) as we cannot guarantee we are in a Rails
        # app with initializers. In a future release this may change to "fast fail" in Rails by
        # checking the config up front.
        sig { returns(T::Hash[String, DefinedJob]) }
        def schedule
          @schedule ||=
            begin
              configuration = Que::Scheduler.configuration
              explicit_schedule = configuration.schedule
              if !explicit_schedule.nil?
                # If an explicit schedule as a hash has been defined, use that.
                from_hash(explicit_schedule)
              elsif File.exist?(configuration.schedule_location)
                # If the schedule is defined as a file location, then load it and return it.
                from_file(configuration.schedule_location)
              else
                raise "No que-scheduler config set, or file found " \
                      "at #{configuration.schedule_location}"
              end
            end
        end

        sig { params(location: T.any(String, Pathname)).returns(T::Hash[String, DefinedJob]) }
        def from_file(location)
          from_yaml(File.read(location))
        end

        sig { params(config: String).returns(T::Hash[String, DefinedJob]) }
        def from_yaml(config)
          config_hash = YAML.safe_load(config)
          from_hash(config_hash)
        end

        sig { params(config_hash: Types::SCHEDULE_CONFIG).returns(T::Hash[String, DefinedJob]) }
        def from_hash(config_hash)
          config_hash
            .map { |name, defined_job_hash| hash_item_to_defined_job(name.to_s, defined_job_hash) }
            .index_by(&:name)
        end

        sig do
          params(
            name: String,
            defined_job_hash_in: T::Hash[T.any(String, Symbol), Object]
          ).returns(DefinedJob)
        end
        def hash_item_to_defined_job(name, defined_job_hash_in)
          DefinedJobParser.parse(name, defined_job_hash_in.stringify_keys)
        end
      end
    end

    class << self
      extend T::Sig

      sig { returns(T::Hash[String, DefinedJob]) }
      def schedule
        Schedule.schedule
      end
    end
  end
end
