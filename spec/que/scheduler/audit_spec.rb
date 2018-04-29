require 'spec_helper'

RSpec.describe Que::Scheduler::Audit do
  describe '.append' do
    it 'appends an audit line' do
      job_id = 1234
      executed_at = Time.zone.now.change(usec: 0)
      next_run_at = (Time.zone.now + 1.hour).change(usec: 0)
      missed_jobs = [
        { job_class: HalfHourlyTestJob, queue: 'some_queue', args: [5] },
        { job_class: HalfHourlyTestJob, priority: 80 },
        { job_class: DailyTestJob, queue: 'some_queue', args: [3] }
      ]
      result = Que::Scheduler::EnqueueingCalculator::Result.new(
        missed_jobs: hash_to_enqueues(missed_jobs), job_dictionary: []
      )
      described_class.append(job_id, executed_at, result, next_run_at)

      audit = Que.execute('select * from que_scheduler_audit')
      expect(audit.count).to eq(1)
      expect(audit.first['scheduler_job_id']).to eq(job_id)
      expect(audit.first['executed_at']).to eq(executed_at)
      expect(audit.first['next_run_at']).to eq(next_run_at)
      db_jobs = JSON.parse(audit.first['jobs_enqueued'])
      expect(db_jobs.count).to eq(3)
      expect(db_jobs.first).to eq(
        'job_class' => 'HalfHourlyTestJob',
        'queue' => 'some_queue',
        'args' => [5]
      )
      expect(db_jobs).to eq(
        [
          { 'job_class' => 'HalfHourlyTestJob', 'queue' => 'some_queue', 'args' => [5] },
          { 'job_class' => 'HalfHourlyTestJob', 'priority' => 80, 'args' => [] },
          { 'job_class' => 'DailyTestJob', 'queue' => 'some_queue', 'args' => [3] }
        ]
      )
    end
  end
end
