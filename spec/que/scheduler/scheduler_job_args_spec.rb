require 'spec_helper'
require 'timecop'

RSpec.describe Que::Scheduler::SchedulerJobArgs do
  it 'should prepare default args' do
    Timecop.freeze do
      apply_db_time_now
      args = described_class.build(nil)
      expect(args.last_run_time).to eq(Time.zone.now)
      expect(args.as_time).to eq(Time.zone.now)
      expect(args.job_dictionary).to eq([])
    end
  end

  describe 'should parse current args' do
    let(:last_time) { Time.zone.now - 45.minutes }
    let(:dictionary) { %w[HalfHourlyTestJob OldRemovedJob] }

    def attempt_parse(options)
      Timecop.freeze do
        apply_db_time_now
        args = described_class.build(options)
        expect(args.last_run_time.iso8601).to eq(last_time.iso8601)
        expect(args.as_time).to eq(Time.zone.now)
        expect(args.job_dictionary).to eq(dictionary)
      end
    end

    it 'as symbols' do
      attempt_parse(
        last_run_time: last_time.iso8601,
        job_dictionary: dictionary
      )
    end

    it 'as strings' do
      attempt_parse(
        'last_run_time' => last_time.iso8601,
        'job_dictionary' => dictionary
      )
    end
  end
end
