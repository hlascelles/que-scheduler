require "que"

ALL_TEST_JOB_NAMES = %w[
  HalfHourlyTestJob
  SpecifiedByClassTestJob
  WithArgsTestJob
  WithHashArgsTestJob
  WithNilArgTestJob
  DailyTestJob
  TwiceDailyTestJob
  TimezoneTestJob
].freeze

ALL_TEST_JOB_NAMES.each do |name|
  clazz =
    if Que::Scheduler::ToEnqueue.active_job_sufficient_version?

      Class.new(::ActiveJob::Base) do
        self.queue_adapter = :que

        def run; end
      end
    else
      Class.new(::Que::Job) do
        def run; end
      end

    end
  Object.const_set(name, clazz)
end

class NotAQueJob
  def run; end
end
