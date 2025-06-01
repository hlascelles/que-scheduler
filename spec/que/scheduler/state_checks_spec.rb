require "spec_helper"

RSpec.describe Que::Scheduler::StateChecks do
  describe ".check" do
    it "detects when a migration has not been performed" do
      Que::Scheduler::Migrations.migrate!(version: 3)
      max = Que::Scheduler::Migrations::MAX_VERSION
      expect { described_class.check }.to raise_error(
        /The que-scheduler db migration state was found to be 3. It should be #{max}./
      )
    end

    it "detects when multiple scheduler jobs are enqueued" do
      Que::Scheduler::SchedulerJob.enqueue # First one is OK
      expect { Que::Scheduler::SchedulerJob.enqueue }.to raise_error(
        /#{Regexp.quote('Key (job_class)=(Que::Scheduler::SchedulerJob) already exists')}/
      )
    end
  end

  describe ".assert_db_migrated" do
    [
      true,
      false,
    ].each do |k|
      it "detects when running in synchronous mode #{k}" do
        expect(Que::Scheduler::Migrations).to receive(:db_version).and_return(0)
        Que.run_synchronously = k
        expect { described_class.send(:assert_db_migrated) }.to raise_error do |err|
          expect(err.message.include?("synchronous mode")).to eq k
        end
      end
    end
  end
end
