# typed: true

require "fugit"
require "sorbet-runtime"
require_relative "defined_job"
require_relative "job_adapters"
require_relative "schedule_type"

# Turns one job's entry in the schedule config into a validated DefinedJob.
module Que
  module Scheduler
    module DefinedJobParser
      # One job's entry in the schedule, with string keys
      CONFIG = T.type_alias { T::Hash[String, Object] }

      class << self
        extend T::Sig

        sig { params(name: String, config: CONFIG).returns(DefinedJob) }
        def parse(name, config)
          DefinedJob.new(
            name: name,
            job_class: parse_job_class(name, config),
            cron: parse_cron(name, config),
            queue: parse_queue(name, config),
            priority: parse_priority(name, config),
            args_array: parse_args(config),
            schedule_type: parse_schedule_type(name, config)
          )
        end

        sig { params(name: String, config: CONFIG).returns(Class) }
        private def parse_job_class(name, config)
          class_name = String(config.fetch("class", name))
          job_class = Object.const_get(class_name)
          return job_class if job_class.is_a?(Class) && JobAdapters.supports?(job_class)

          reason = "Job #{class_name} was not a supported job type"
          raise_invalid(name, :job_class, class_name, reason)
        end

        sig { params(name: String, config: CONFIG).returns(Fugit::Cron) }
        private def parse_cron(name, config)
          value = config["cron"]
          # An invalid cron parses to nil
          Fugit::Cron.parse(value) || raise_invalid(name, :cron, value, "cron must be present")
        end

        sig { params(name: String, config: CONFIG).returns(T.nilable(String)) }
        private def parse_queue(name, config)
          value = config["queue"]
          return value if value.nil? || value.is_a?(String)

          raise_invalid(name, :queue, value, "queue must be a string")
        end

        sig { params(name: String, config: CONFIG).returns(T.nilable(Integer)) }
        private def parse_priority(name, config)
          value = config["priority"]
          return value if value.nil? || value.is_a?(Integer)

          raise_invalid(name, :priority, value, "priority must be an integer")
        end

        # Que stores args as a json array. A single value (including a hash or nil) becomes an
        # array of that one value.
        sig { params(config: CONFIG).returns(T::Array[T.anything]) }
        private def parse_args(config)
          return [] unless config.key?("args")

          args = config["args"]
          args.is_a?(Array) ? args : [args]
        end

        sig { params(name: String, config: CONFIG).returns(ScheduleType) }
        private def parse_schedule_type(name, config)
          value = config["schedule_type"]
          return ScheduleType::DEFAULT if value.nil?

          reason = "Not in #{ScheduleType.values.map(&:serialize)}"
          ScheduleType.try_deserialize(String(value)) ||
            raise_invalid(name, :schedule_type, value, reason)
        end

        sig do
          params(name: String, field: Symbol, value: T.anything, reason: String).returns(T.noreturn)
        end
        private def raise_invalid(name, field, value, reason)
          location = Que::Scheduler.configuration.schedule_location
          raise "Invalid #{field} '#{value}' for '#{name}' " \
                "in que-scheduler schedule #{location}.\n#{reason}"
        end
      end
    end
  end
end
