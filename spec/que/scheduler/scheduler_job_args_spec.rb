require 'spec_helper'
require 'timecop'

RSpec.describe Que::Scheduler::SchedulerJobArgs do
  it 'should prepare default args' do
    Timecop.freeze do
      args = described_class.prepare_scheduler_job_args(nil)
      expect(args.last_run_time).to eq(Time.zone.now)
      expect(args.as_time).to eq(Time.zone.now)
      expect(args.job_dictionary).to eq([])
    end
  end

  it 'should parse current args' do
    Timecop.freeze do
      last_time = Time.zone.now - 45.minutes
      dictionary = %w[HalfHourlyTestJob OldRemovedJob]
      args = described_class.prepare_scheduler_job_args(
        last_run_time: last_time.iso8601,
        job_dictionary: dictionary
      )
      expect(args.last_run_time.iso8601).to eq(last_time.iso8601)
      expect(args.as_time).to eq(Time.zone.now)
      expect(args.job_dictionary).to eq(dictionary)
    end
  end
end
