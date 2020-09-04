# typed: false
require "spec_helper"

RSpec.describe Que::Scheduler::Db do
  context "when checking constants" do
    it "has the right scheduler count query string" do
      expect(described_class::SCHEDULER_COUNT_SQL).to eq(
        "SELECT COUNT(*) FROM que_jobs WHERE job_class = '#{Que::Scheduler::SchedulerJob.name}'"
      )
    end
  end

  describe ".count_schedulers" do
    it "returns the right result" do
      expect(described_class.count_schedulers).to eq(0)
      ::Que::Scheduler::SchedulerJob.enqueue
      expect(described_class.count_schedulers).to eq(1)
      ::Que::Scheduler::SchedulerJob.enqueue
      expect(described_class.count_schedulers).to eq(2)
    end
  end

  describe ".now" do
    it "returns the time" do
      expect(Que).to receive(:execute).with(
        described_class::NOW_SQL, []
      ).and_return([{ foo: :bar }])
      expect(described_class.now).to eq(:bar)
    end
  end

  # We hvae users running both ActiveRecord and Sequel. We should not refer to either of them in
  # runtime code.
  describe "ORM usage" do
    def check(str)
      Dir.glob("lib/**/*").select { |file| File.file?(file) }.each do |file|
        expect(File.open(file).grep(/#{str}/)).to be_empty unless file.end_with?("state_checks.rb")
      end
    end

    it "ActiveRecord is not used explicitly" do
      check("ActiveRecord")
    end

    it "Sequel is not used explicitly" do
      check("Sequel")
    end

    # Check Que.transaction is not used, as the config transaction proc should be used instead
    it "Que.transaction is not used explicitly" do
      check("Que.transaction")
    end
  end
end
