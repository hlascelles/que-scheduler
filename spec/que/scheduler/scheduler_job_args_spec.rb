require "spec_helper"
require "timecop"

RSpec.describe Que::Scheduler::SchedulerJobArgs do
  it "prepares default args" do
    Timecop.freeze do
      DbSupport.mock_db_time_now
      args = described_class.build(nil)
      expect(args.last_run_time).to eq(Time.zone.now)
      expect(args.as_time).to eq(Time.zone.now)
      expect(args.job_dictionary).to eq([])
    end
  end

  describe "should parse current args" do
    let(:last_time) { Time.zone.now - 45.minutes }
    let(:dictionary) { %w[HalfHourlyTestJob OldRemovedJob] }

    def attempt_parse(options)
      Timecop.freeze do
        DbSupport.mock_db_time_now
        args = described_class.build(options)
        expect(args.last_run_time.iso8601).to eq(last_time.iso8601)
        expect(args.as_time).to eq(Time.zone.now)
        expect(args.job_dictionary).to eq(dictionary)
      end
    end

    # Since que 1.0 args are always symbols
    it "as symbols" do
      attempt_parse(
        last_run_time: last_time.iso8601,
        job_dictionary: dictionary
      )
    end

    # Ensure we can support que 0.x (strings)
    it "as strings" do
      attempt_parse(
        "last_run_time" => last_time.iso8601,
        "job_dictionary" => dictionary
      )
    end
  end
end
