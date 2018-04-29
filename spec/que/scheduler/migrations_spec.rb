require 'spec_helper'

RSpec.describe Que::Scheduler::Migrations do
  describe '.migrate!' do
    it 'migrates up and down versions' do
      # Readd the job that was removed by the rspec before all
      ::Que::Scheduler::SchedulerJob.enqueue
      described_class.db_version
      expect(described_class.db_version).to eq(2)
      expect(audit_table_exists?).to be true
      described_class.migrate!(version: 1)
      expect(described_class.db_version).to eq(1)
      expect(jobs_by_class(Que::Scheduler::SchedulerJob).count).to eq(1)
      expect(audit_table_exists?).to be false
      described_class.migrate!(version: 0)
      expect(described_class.db_version).to eq(0)
      expect(jobs_by_class(Que::Scheduler::SchedulerJob).count).to eq(0)
      described_class.migrate!(version: 1)
      expect(described_class.db_version).to eq(1)
      expect(jobs_by_class(Que::Scheduler::SchedulerJob).count).to eq(1)
      expect(audit_table_exists?).to be false
      described_class.migrate!(version: 2)
      expect(described_class.db_version).to eq(2)
      expect(audit_table_exists?).to be true
    end

    def audit_table_exists?
      ActiveRecord::Base.connection.table_exists?(Que::Scheduler::Audit::TABLE_NAME)
    end
  end
end
