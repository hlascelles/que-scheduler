require 'que'

class HalfHourlyTestJob < ::Que::Job
  def run; end
end

class SpecifiedByClassTestJob < ::Que::Job
  def run; end
end

class WithArgsTestJob < ::Que::Job
  def run; end
end

class DailyTestJob < ::Que::Job
  def run; end
end

class TwiceDailyTestJob < ::Que::Job
  def run; end
end

class TimezoneTestJob < ::Que::Job
  def run; end
end

class NotAQueJob
  def run; end
end
