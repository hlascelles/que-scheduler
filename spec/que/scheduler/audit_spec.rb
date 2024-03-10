require "spec_helper"

RSpec.describe Que::Scheduler::Audit do
  include_context "when job testing"
  include_context "when audit testing"

  describe ".append" do
    def append_test_jobs(scheduler_job_id, executed_at, enqueued)
      described_class.append(scheduler_job_id, executed_at, enqueued)

      audit = find_audit_rows(expect: 1)
      expect(audit.first[:scheduler_job_id]).to eq(scheduler_job_id)
      expect(audit.first[:executed_at]).to eq(executed_at)

      db_jobs = find_audit_enqueued_rows(expect: 3)
      DbSupport.convert_args_column(db_jobs)
      expect(db_jobs.count).to eq(enqueued.count)
      db_jobs
    end

    it "appends an audit line" do
      Timecop.freeze do
        scheduler_job_id = 1234
        # Roundtripping through postgres can yield usec differences which give spurious
        # spec failures, so we ignore usec.
        audit_insertion_time = Time.zone.now.change(usec: 0)
        jobs_set_to_run_at = Que::Scheduler::Db.now.change(usec: 0)

        enqueued = enqueue_test_jobs_for_audit
        # Do the other part of the usec removal from above here
        db_jobs = append_test_jobs(scheduler_job_id, audit_insertion_time, enqueued).each { |row|
          row[:run_at] = row[:run_at].change(usec: 0)
        }

        expect(db_jobs).to eq(
          [
            {
              id: 1,
              scheduler_job_id: scheduler_job_id,
              job_class: "HalfHourlyTestJob",
              queue: handles_queue_name ? "something1" : nil,
              priority: 100,
              args: [5],
              job_id: enqueued[0].job_id,
              run_at: jobs_set_to_run_at,
            },
            {
              id: 2,
              scheduler_job_id: scheduler_job_id,
              job_class: "HalfHourlyTestJob",
              queue: handles_queue_name ? Que::Scheduler.configuration.que_scheduler_queue : nil,
              priority: 80,
              args: [],
              job_id: enqueued[1].job_id,
              run_at: jobs_set_to_run_at,
            },
            {
              id: 3,
              scheduler_job_id: scheduler_job_id,
              job_class: "DailyTestJob",
              queue: handles_queue_name ? "something3" : nil,
              priority: 42,
              args: [3],
              job_id: enqueued[2].job_id,
              run_at: jobs_set_to_run_at,
            },
          ]
        )
      end
    end
  end
end
