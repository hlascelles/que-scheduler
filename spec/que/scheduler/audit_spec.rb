require 'spec_helper'

RSpec.describe Que::Scheduler::Audit do
  include_context 'job testing'

  describe '.append' do
    def append_test_jobs(enqueued, executed_at, job_id)
      described_class.append(job_id, executed_at, enqueued)

      audit = Que::Scheduler::VersionSupport.execute('select * from que_scheduler_audit')
      expect(audit.count).to eq(1)
      expect(audit.first[:scheduler_job_id]).to eq(job_id)
      expect(audit.first[:executed_at]).to eq(executed_at)

      db_jobs =
        Que::Scheduler::VersionSupport.execute('select * from que_scheduler_audit_enqueued')
      DbSupport.convert_args_column(db_jobs)
      expect(db_jobs.count).to eq(enqueued.count)
      db_jobs
    end

    it 'appends an audit line' do
      Timecop.freeze do
        scheduler_job_id = 1234
        # Roundtripping through postgres can yield usec differences which give spurious
        # spec failures, so we ignore usec.
        audit_insertion_time = Time.zone.now.change(usec: 0)
        jobs_set_to_run_at = Que::Scheduler::Db.now.change(usec: 0)

        te = Que::Scheduler::ToEnqueue
        to_enqueue = [
          te.create(job_class: HalfHourlyTestJob, args: 5, queue: 'something1'),
          te.create(job_class: HalfHourlyTestJob, priority: 80),
          te.create(job_class: DailyTestJob, args: 3, queue: 'something3', priority: 42),
        ]

        enqueued = to_enqueue.map(&:enqueue)
        db_jobs = append_test_jobs(enqueued, audit_insertion_time, scheduler_job_id)

        expect(db_jobs).to eq(
          [
            {
              scheduler_job_id: scheduler_job_id,
              job_class: 'HalfHourlyTestJob',
              queue: handles_queue_name ? 'something1' : nil,
              priority: 100,
              args: [5],
              job_id: enqueued[0].job_id,
              run_at: jobs_set_to_run_at,
            },
            {
              scheduler_job_id: scheduler_job_id,
              job_class: 'HalfHourlyTestJob',
              queue: handles_queue_name ? Que::Scheduler.configuration.que_scheduler_queue : nil,
              priority: 80,
              args: [],
              job_id: enqueued[1].job_id,
              run_at: jobs_set_to_run_at,
            },
            {
              scheduler_job_id: scheduler_job_id,
              job_class: 'DailyTestJob',
              queue: handles_queue_name ? 'something3' : nil,
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
