require "spec_helper"

RSpec.describe Que::Scheduler::Migrations do
  def check_index_existence(expect)
    indices = ActiveRecord::Base.connection.execute(
      "SELECT * FROM pg_indexes WHERE tablename = 'que_scheduler_audit'"
    ).to_a.map { |r| r.fetch("indexname") }
    exist = indices.include?("index_que_scheduler_audit_on_scheduler_job_id")
    expect(exist).to eq(expect)
  end

  describe ".migrate!" do
    # rubocop:disable RSpec/MultipleExpectations
    # rubocop:disable RSpec/ExampleLength
    it "migrates up and down versions" do
      # Readd the job that was removed by the rspec before all
      ::Que::Scheduler::SchedulerJob.enqueue
      ::Que::Scheduler::StateChecks.check

      expect(described_class.db_version).to eq(5)

      # Check 5 change down
      check_index_existence(false)
      described_class.migrate!(version: 4)
      check_index_existence(true)
      expect(described_class.db_version).to eq(4)

      # Check 4 change down
      expect(DbSupport.scheduler_job_id_type).to eq("bigint")
      described_class.migrate!(version: 3)
      expect(DbSupport.scheduler_job_id_type).to eq("integer")
      expect(described_class.db_version).to eq(3)

      # Check 3 change down
      expect(DbSupport.enqueued_table_exists?).to be true
      described_class.migrate!(version: 2)
      expect(described_class.db_version).to eq(2)
      expect(DbSupport.enqueued_table_exists?).to be false

      # Check 2 change down
      expect(described_class.audit_table_exists?).to be true
      described_class.migrate!(version: 1)
      expect(described_class.db_version).to eq(1)
      expect(described_class.audit_table_exists?).to be false

      # Check 1 change down
      expect(Que::Scheduler::Db.count_schedulers).to eq(1)
      described_class.migrate!(version: 0)
      expect(described_class.db_version).to eq(0)
      expect(Que::Scheduler::Db.count_schedulers).to eq(0)

      # Check 1 change up
      described_class.migrate!(version: 1)
      expect(described_class.db_version).to eq(1)
      expect(Que::Scheduler::Db.count_schedulers).to eq(1)

      # Check 2 change up
      expect(described_class.audit_table_exists?).to be false
      described_class.migrate!(version: 2)
      expect(described_class.db_version).to eq(2)
      expect(described_class.audit_table_exists?).to be true

      # Check 3 change up
      # Add a row to check conversion from schema 2 to schema 3
      Que::Scheduler::VersionSupport.execute(<<-SQL)
        INSERT INTO que_scheduler_audit
        VALUES (17, '2017-01-01', '2017-01-02', '[{"args": [1, 2], "job_class": "DailyTestJob"}]');
      SQL
      described_class.migrate!(version: 3)
      expect(described_class.db_version).to eq(3)
      expect(DbSupport.enqueued_table_exists?).to be true
      expect(DbSupport.scheduler_job_id_type).to eq("integer")
      # Check the row came through correctly
      audit = Que::Scheduler::VersionSupport.execute("SELECT * FROM que_scheduler_audit")
      expect(audit.count).to eq(1)
      expect(audit.first[:scheduler_job_id]).to eq(17)
      expect(audit.first[:executed_at].to_s).to start_with("2017-01-01 00:00:00")
      # .. with the associated enqueued row
      audit = Que::Scheduler::VersionSupport.execute("SELECT * FROM que_scheduler_audit_enqueued")
      DbSupport.convert_args_column(audit)
      expect(audit.count).to eq(1)
      expect(audit.first[:scheduler_job_id]).to eq(17)
      expect(audit.first[:job_class]).to eq("DailyTestJob")
      expect(audit.first[:args]).to eq([1, 2])

      # Check 4 change up
      described_class.migrate!(version: 4)
      expect(described_class.db_version).to eq(4)
      expect(DbSupport.scheduler_job_id_type).to eq("bigint")
      audit = Que::Scheduler::VersionSupport.execute("SELECT * FROM que_scheduler_audit")
      expect(audit.first[:scheduler_job_id]).to eq(17)
      audit = Que::Scheduler::VersionSupport.execute("SELECT * FROM que_scheduler_audit_enqueued")
      expect(audit.first[:scheduler_job_id]).to eq(17)

      # Check 5 change up
      check_index_existence(true)
      described_class.migrate!(version: 5)
      check_index_existence(false)

      Que::Scheduler::StateChecks.check
    end
    # rubocop:enable RSpec/MultipleExpectations
    # rubocop:enable RSpec/ExampleLength

    it "returns the right migration number if the job has been deliberately deleted" do
      Que::Scheduler::VersionSupport.execute("DELETE FROM que_jobs")
      expect(Que::Scheduler::Db.count_schedulers).to eq(0)
      expect(described_class.audit_table_exists?).to be true
      expect(described_class.db_version).to eq(described_class::MAX_VERSION)
    end

    # When que-testing is present, calls to Que::Scheduler::VersionSupport.execute do nothing and
    # return an empty array.
    # Thus, trying to migrate a test database will always fail. It is safer to do nothing and not
    # create the que-scheduler tables. This follows the logic of que, which does not create its
    # tables either.
    it "does nothing, and doesn't error, when using que-testing" do
      described_class.migrate!(version: 0)
      stub_const("Que::Testing", true)
      described_class.migrate!(version: described_class::MAX_VERSION)
      expect(described_class.audit_table_exists?).to be false
    end
  end

  describe "DB health" do
    it "has no duplicate indices" do
      # From https://wiki.postgresql.org/wiki/Index_Maintenance
      result = Que::Scheduler::VersionSupport.execute(<<-SQL)
        SELECT pg_size_pretty(SUM(pg_relation_size(idx))::BIGINT) AS SIZE,
               (array_agg(idx))[1] AS idx1, (array_agg(idx))[2] AS idx2,
               (array_agg(idx))[3] AS idx3, (array_agg(idx))[4] AS idx4
        FROM (
            SELECT indexrelid::regclass AS idx, (indrelid::text ||E'\n'|| indclass::text ||E'\n'|| indkey::text ||E'\n'||
                                                 COALESCE(indexprs::text,'')||E'\n' || COALESCE(indpred::text,'')) AS KEY
            FROM pg_index) sub
        GROUP BY KEY HAVING COUNT(*)>1
        ORDER BY SUM(pg_relation_size(idx)) DESC;
      SQL
      expect(result.count).to eq(0)
    end
  end
end
