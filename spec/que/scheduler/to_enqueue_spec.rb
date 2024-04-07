require "spec_helper"
RSpec.describe Que::Scheduler::ToEnqueue do
  describe Que::Scheduler::ActiveJobType do
    describe "#extract_scheduled_at" do
      around do |example|
        Timecop.freeze do
          example.run
        end
      end

      let(:test_time) { Time.zone.now.change(usec: 0) + 1.hour }

      it "handles a float" do
        result = described_class.send(:extract_scheduled_at, test_time.to_f)
        expect(result).to eq(Que::Scheduler::TimeZone.time_zone.parse(test_time.to_s))
      end

      it "handles a string" do
        result = described_class.send(:extract_scheduled_at, test_time.to_s)
        expect(result).to eq(Que::Scheduler::TimeZone.time_zone.parse(test_time.to_s))
      end
    end
  end
end
