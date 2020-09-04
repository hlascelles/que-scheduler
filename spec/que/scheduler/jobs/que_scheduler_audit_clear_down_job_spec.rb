# typed: false
require "spec_helper"

RSpec.describe Que::Scheduler::Jobs::QueSchedulerAuditClearDownJob do
  include_context "when audit testing"

  def insert_test_rows
    now = Que::Scheduler::Db.now
    initial = 10
    initial.times { |i|
      enqueued = enqueue_test_jobs_for_audit
      Que::Scheduler::Audit.append(i, now - i.seconds, enqueued)
    }
    initial
  end

  describe "#run" do
    it "clears down a given number of audit rows" do
      initial = insert_test_rows

      retain = 2
      audit_rows = find_audit_rows(expect: initial)
      audit_enqueued_rows = find_audit_enqueued_rows(expect: initial * test_jobs_for_audit_count)

      expect_rows = audit_rows.last(retain)
      expect_audit_enqueued_count = retain * test_jobs_for_audit_count
      expect_enqueued_rows = audit_enqueued_rows.last(expect_audit_enqueued_count)

      described_class.run(retain_row_count: retain)

      expect(find_audit_rows(expect: retain)).to eq(expect_rows)
      expect(find_audit_enqueued_rows(expect: expect_audit_enqueued_count))
        .to eq(expect_enqueued_rows)
    end

    it "doesn't clear down rows if there are fewer than the retain_row_count" do
      initial = insert_test_rows
      retain = initial + 5

      described_class.run(retain_row_count: retain)

      find_audit_rows(expect: initial)
    end

    it "does nothing if no audit rows" do
      find_audit_rows(expect: 0)
      expect {
        described_class.run(retain_row_count: 2)
      }.not_to raise_error
    end
  end
end
