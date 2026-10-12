require "spec_helper"

RSpec.describe Que::Scheduler::ActiveJobAdapter do
  describe ".extract_scheduled_at" do
    it "parses the ISO 8601 string ActiveJob serialises" do
      test_time = Time.zone.now.change(usec: 0) + 1.hour
      result = described_class.extract_scheduled_at(test_time.utc.iso8601(9))
      expect(result).to eq(test_time)
    end
  end
end
