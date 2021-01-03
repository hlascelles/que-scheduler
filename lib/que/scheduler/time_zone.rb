module Que
  module Scheduler
    module TimeZone
      BOTH_CONFIG_AND_TIME_DOT_ZONE_SET = <<~ERR.freeze
        The que-scheduler config for time_zone has been set to a non-nil value, but
        it appears to also have been set on Time.zone (possibly by Rails). Both of these
        cannot be non-nil.
        You should remove the time_zone config from the que-scheduler config block.
      ERR

      TIME_ZONE_COULD_NOT_BE_DETERMINED = <<~ERR.freeze
        It appears Time.zone is nil. This prevents proper functioning of que-scheduler.

        Resolving this issue depends on your application setup.

        1) If you are using Rails, set the standard time_zone config
           eg:
           ```
           # In application.rb
           config.time_zone = "Europe/London"
           ```

        2) If you are not using Rails, set your time zone in the que-scheduler config:
           eg:
           ```
           Que::Scheduler.configure do |config|
             config.time_zone = "Europe/London"
           end
           ```
      ERR

      TIME_ZONE_CONFIG_IS_NOT_VALID = <<~ERR.freeze
        The que-scheduler config for time_zone has been set to a non-nil value, but that value
        does not yield a real time zone when passed to ActiveSupport::TimeZone.new
      ERR

      class << self
        def time_zone
          @time_zone ||=
            begin
              time_dot_zone = Time.zone
              if time_dot_zone.present?
                if Que::Scheduler.configuration.time_zone.present?
                  raise BOTH_CONFIG_AND_TIME_DOT_ZONE_SET
                end

                time_dot_zone
              elsif Que::Scheduler.configuration.time_zone
                new_tz = ActiveSupport::TimeZone.new(Que::Scheduler.configuration.time_zone)
                raise TIME_ZONE_CONFIG_IS_NOT_VALID unless new_tz

                new_tz
              else
                raise TIME_ZONE_COULD_NOT_BE_DETERMINED
              end
            end
        end
      end
    end
  end
end
