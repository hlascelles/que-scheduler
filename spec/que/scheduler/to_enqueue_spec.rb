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

      it "handles a string" do
        result = described_class.send(:extract_scheduled_at, test_time.utc.iso8601(9))
        expect(result).to eq(test_time)
      end

      it "handles nil" do
        expect(described_class.send(:extract_scheduled_at, nil)).to be_nil
      end
    end
  end
end
