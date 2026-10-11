# typed: true

# TimeWithZone delegates this to Time via method_missing, so tapioca does not see it.

class ActiveSupport::TimeWithZone
  sig { returns(ActiveSupport::TimeWithZone) }
  def beginning_of_minute; end
end
