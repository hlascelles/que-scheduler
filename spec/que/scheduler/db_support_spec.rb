require "spec_helper"

RSpec.describe Que::Scheduler::DbSupport do
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

  describe ".job_attributes" do
    it "retrieves the job attributes in a consistent manner" do
      job = Que::Scheduler::SchedulerJob.enqueue

      expected =
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
end
