require 'que'
require 'active_job'
require 'active_job/queue_adapters/que_adapter'

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

class TestActiveJob < ::ActiveJob::Base
  self.queue_adapter = :que
  def run; end
end
