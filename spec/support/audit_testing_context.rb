# typed: false
shared_context "when audit testing" do
  let(:test_jobs_for_audit_count) { 3 }

  def enqueue_test_jobs_for_audit
    te = Que::Scheduler::ToEnqueue
    items = [
      te.create(job_class: HalfHourlyTestJob, args: 5, queue: "something1"),
      te.create(job_class: HalfHourlyTestJob, priority: 80),
      te.create(job_class: DailyTestJob, args: 3, queue: "something3", priority: 42),
    ]
    expect(items.count).to eq(test_jobs_for_audit_count)
    items.map(&:enqueue)
  end

  def find_audit_rows(expect:)
    find_audit_table_rows("que_scheduler_audit", expect)
  end

  def find_audit_enqueued_rows(expect:)
    find_audit_table_rows("que_scheduler_audit_enqueued", expect)
  end

  private

  def find_audit_table_rows(table, expect_count)
    sql = "SELECT * FROM #{table} ORDER BY scheduler_job_id"
    Que::Scheduler::VersionSupport.execute(sql).tap do |audit|
      expect(audit.count).to eq(expect_count)
    end
  end
end
