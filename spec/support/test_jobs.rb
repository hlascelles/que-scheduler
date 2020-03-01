require 'que'

%w[
  HalfHourlyTestJob
  SpecifiedByClassTestJob
  WithArgsTestJob
  DailyTestJob
  TwiceDailyTestJob
  TimezoneTestJob
].each do |name|
  clazz =
    if Que::Scheduler::JobTypeSupport::active_job_sufficient_version?
      require 'active_job'
      require 'active_job/queue_adapters/que_adapter'

      Class.new(::ActiveJob::Base) do
        self.queue_adapter = :que

        def run
        end
      end
    else
      Class.new(::Que::Job) do
        def run
        end
      end

    end
  Object.const_set(name,clazz)
end

class NotAQueJob
  def run; end
end
