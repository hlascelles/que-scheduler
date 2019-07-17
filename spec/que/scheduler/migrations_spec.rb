require 'spec_helper'

RSpec.describe Que::Scheduler::Migrations do
  describe '.migrate!' do
    it 'migrates up and down versions' do
      # Readd the job that was removed by the rspec before all
      ::Que::Scheduler::SchedulerJob.enqueue

      expect(described_class.db_version).to eq(4)
      expect(DbSupport.scheduler_job_id_type).to eq('bigint')
      described_class.migrate!(version: 3)
      expect(DbSupport.scheduler_job_id_type).to eq('integer')
      expect(described_class.db_version).to eq(3)
      expect(DbSupport.enqueued_table_exists?).to be true
      described_class.migrate!(version: 2)
      expect(described_class.db_version).to eq(2)
      expect(DbSupport.enqueued_table_exists?).to be false
      expect(Que::Scheduler::Migrations.audit_table_exists?).to be true
      described_class.migrate!(version: 1)
      expect(described_class.db_version).to eq(1)
      expect(Que::Scheduler::Db.count_schedulers).to eq(1)
      expect(Que::Scheduler::Migrations.audit_table_exists?).to be false
      described_class.migrate!(version: 0)
      expect(described_class.db_version).to eq(0)
      expect(Que::Scheduler::Db.count_schedulers).to eq(0)
      described_class.migrate!(version: 1)
      expect(described_class.db_version).to eq(1)
      expect(Que::Scheduler::Db.count_schedulers).to eq(1)
      expect(Que::Scheduler::Migrations.audit_table_exists?).to be false
      described_class.migrate!(version: 2)
      expect(described_class.db_version).to eq(2)
      expect(Que::Scheduler::Migrations.audit_table_exists?).to be true

      # Add a row to check conversion from schema 2 to schema 3
      Que::Scheduler::VersionSupport.execute(<<-SQL)
        INSERT INTO que_scheduler_audit
        VALUES (17, '2017-01-01', '2017-01-02', '[{"args": [1, 2], "job_class": "DailyTestJob"}]');
      SQL

      described_class.migrate!(version: 3)
      expect(described_class.db_version).to eq(3)
      expect(DbSupport.enqueued_table_exists?).to be true
      expect(DbSupport.scheduler_job_id_type).to eq('integer')

      # Check the row came through correctly
      audit = Que::Scheduler::VersionSupport.execute('SELECT * FROM que_scheduler_audit')
      expect(audit.count).to eq(1)
      expect(audit.first[:scheduler_job_id]).to eq(17)
      expect(audit.first[:executed_at].to_s).to start_with('2017-01-01 00:00:00')
      audit = Que::Scheduler::VersionSupport.execute('SELECT * FROM que_scheduler_audit_enqueued')
      expect(audit.count).to eq(1)
      expect(audit.first[:scheduler_job_id]).to eq(17)
      expect(audit.first[:job_class]).to eq('DailyTestJob')
      expect(audit.first[:args].to_s).to eq('[1, 2]')

      described_class.migrate!(version: 4)
      expect(DbSupport.scheduler_job_id_type).to eq('bigint')
      audit = Que::Scheduler::VersionSupport.execute('SELECT * FROM que_scheduler_audit')
      expect(audit.first[:scheduler_job_id]).to eq(17)
      audit = Que::Scheduler::VersionSupport.execute('SELECT * FROM que_scheduler_audit_enqueued')
      expect(audit.first[:scheduler_job_id]).to eq(17)
    end

    it 'returns the right migration number if the job has been deliberately deleted' do
      Que::Scheduler::VersionSupport.execute('DELETE FROM que_jobs')
      expect(Que::Scheduler::Db.count_schedulers).to eq(0)
      expect(Que::Scheduler::Migrations.audit_table_exists?).to be true
      expect(described_class.db_version).to eq(Que::Scheduler::Migrations::MAX_VERSION)
    end

    # When que-testing is present, calls to Que::Scheduler::VersionSupport.execute do nothing and
    # return an empty array.
    # Thus, trying to migrate a test database will always fail. It is safer to do nothing and not
    # create the que-scheduler tables. This follows the logic of que, which does not create its
    # tables either.
    it "does nothing, and doesn't error, when using que-testing" do
      described_class.migrate!(version: 0)
      stub_const('Que::Testing', true)
      described_class.migrate!(version: 4)
      expect(Que::Scheduler::Migrations.audit_table_exists?).to be false
    end
  end
end
