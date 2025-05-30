require "spec_helper"

RSpec.describe Que::Scheduler::VersionSupport do
  describe ".apply_retry_semantics" do
    let(:test_class) do
      Que::Scheduler::SchedulerJob
    end

    it "sets the retries" do
      # Directly check the inlined logic
      expect(test_class.maximum_retry_count).to be > 10_000_000
      expect(test_class.retry_interval).to be_a(Proc)
      expect(test_class.retry_interval.call(6)).to eq(1299)
      expect(test_class.retry_interval.call(8)).to eq(3600)
      expect(test_class.maximum_retry_count).to be > 10_000_000
    end
  end

  describe "RETRY_PROC" do
    it "sets the proc" do
      expect(described_class::RETRY_PROC.call(6)).to eq(1299)
      expect(described_class::RETRY_PROC.call(7)).to eq(2404)
      expect(described_class::RETRY_PROC.call(8)).to eq(3600)
      expect(described_class::RETRY_PROC.call(9)).to eq(3600)
    end
  end

  describe ".job_attributes" do
    it "retrieves the job attributes in a consistent manner" do
      job = Que::Scheduler::SchedulerJob.enqueue

      expected =
        if described_class.zero_major?
          hash_including(
            args: [],
            error_count: 0,
            job_class: "Que::Scheduler::SchedulerJob",
            last_error: nil,
            priority: 0,
            queue: ""
          )
        else
          hash_including(
            args: [],
            data: {},
            error_count: 0,
            expired_at: nil,
            finished_at: nil,
            job_class: "Que::Scheduler::SchedulerJob",
            last_error_backtrace: nil,
            last_error_message: nil,
            priority: 0,
            queue: "default"
          )
        end
      attrs = described_class.job_attributes(job)
      expect(attrs).to match(expected)
      # Keys changed from strings to symbols with que 1.0
      # We consolidate on symbols.
      attrs.each_key do |key|
        expect(key).to be_a(Symbol)
      end
      expect(attrs.fetch(:job_id)).to be_a(Integer)
      expect(attrs.fetch(:run_at)).to be_a(Time)
    end
  end

  describe "major checks" do
    before(:each) do
      Dememoize.remove_instance_variable_if_defined(described_class, "@zero_major")
      Dememoize.remove_instance_variable_if_defined(described_class, "@one_major")
      Dememoize.remove_instance_variable_if_defined(described_class, "@que_version")
    end

    context "when not one" do
      before do
        expect(described_class).to receive(:que_version).and_return("0.14.0")
      end

      it "returns the right value for zero_major?" do
        expect(described_class.zero_major?).to be(true)
      end

      it "returns the right value for one_major?" do
        expect(described_class.one_major?).to be(false)
      end
    end

    context "when one" do
      before do
        expect(described_class).to receive(:que_version).and_return("1.0.0")
      end

      it "returns the right value for zero_major?" do
        expect(described_class.zero_major?).to be(false)
      end

      it "returns the right value for one_major?" do
        expect(described_class.one_major?).to be(true)
      end
    end
  end
end
