require 'spec_helper'

RSpec.describe Que::Scheduler::StateChecks do
  describe '.check' do
    it 'detects when a migration has not been performed' do
      Que::Scheduler::Migrations.migrate!(version: 3)
      max = Que::Scheduler::Migrations::MAX_VERSION
      expect { described_class.check }.to raise_error(
        /The que-scheduler db migration state was found to be 3. It should be #{max}./
      )
    end

    it 'detects when multiple scheduler jobs are enqueued' do
      2.times { Que::Scheduler::SchedulerJob.enqueue }
      expect { described_class.check }.to raise_error(
        /Only one Que::Scheduler::SchedulerJob should be enqueued. 2 were found./
      )
    end
  end
end
