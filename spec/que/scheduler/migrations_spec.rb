require 'spec_helper'

RSpec.describe Que::Scheduler::Migrations do
  describe '.migrate!' do
    it 'migrates up and down versions' do
      # Readd the job that was removed by the rspec before all
      ::Que::Scheduler::SchedulerJob.enqueue

      expect(described_class.db_version).to eq(4)
      expect(scheduler_job_id_type).to eq('bigint')
      described_class.migrate!(version: 3)
      expect(scheduler_job_id_type).to eq('integer')
      expect(described_class.db_version).to eq(3)
      expect(enqueued_rows_exists?).to be true
      described_class.migrate!(version: 2)
      expect(described_class.db_version).to eq(2)
      expect(enqueued_rows_exists?).to be false
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

      # Add a row to check conversion from schema 2 to schema 3
      Que.execute(<<-SQL)
        INSERT INTO que_scheduler_audit
        VALUES (17, '2017-01-01', '2017-01-02', '[{"args": [1, 2], "job_class": "DailyTestJob"}]');
      SQL

      described_class.migrate!(version: 3)
      expect(described_class.db_version).to eq(3)
      expect(enqueued_rows_exists?).to be true
      expect(scheduler_job_id_type).to eq('integer')

      # Check the row came through correctly
      audit = Que.execute('SELECT * FROM que_scheduler_audit')
      expect(audit.count).to eq(1)
      expect(audit.first[:scheduler_job_id]).to eq(17)
      expect(audit.first[:executed_at].to_s).to start_with('2017-01-01 00:00:00')
      audit = Que.execute('SELECT * FROM que_scheduler_audit_enqueued')
      expect(audit.count).to eq(1)
      expect(audit.first[:scheduler_job_id]).to eq(17)
      expect(audit.first[:job_class]).to eq('DailyTestJob')
      expect(audit.first[:args].to_s).to eq('[1, 2]')

      described_class.migrate!(version: 4)
      expect(scheduler_job_id_type).to eq('bigint')
      audit = Que.execute('SELECT * FROM que_scheduler_audit')
      expect(audit.first[:scheduler_job_id]).to eq(17)
      audit = Que.execute('SELECT * FROM que_scheduler_audit_enqueued')
      expect(audit.first[:scheduler_job_id]).to eq(17)
    end

    def scheduler_job_id_type
      Que.execute(
        'select column_name, data_type from information_schema.columns ' \
        "where table_name = 'que_scheduler_audit';"
      ).find { |row| row.fetch('column_name') == 'scheduler_job_id' }.fetch('data_type')
    end

    def audit_table_exists?
      ActiveRecord::Base.connection.table_exists?(Que::Scheduler::Audit::TABLE_NAME)
    end

    def enqueued_rows_exists?
      ActiveRecord::Base.connection.table_exists?(Que::Scheduler::Audit::ENQUEUED_TABLE_NAME)
    end
  end
end
