RSpec.shared_context 'roundtrip tester' do
  let(:run_time) { Time.zone.parse('2017-11-08T13:50:32') }
  let(:full_dictionary) { ::Que::Scheduler::DefinedJob.defined_jobs.map(&:name) }

  around(:each) do |example|
    Timecop.freeze(run_time) do
      example.run
    end
  end

  before(:each) do
    mock_db_time_now
  end

  def run_test(initial_job_args, to_be_scheduled)
    Que::Scheduler::SchedulerJob.enqueue(initial_job_args)
    ::Que::Job.work
    expect_itself_enqueued
    all_enqueued = Que.job_stats.map do |job|
      job.symbolize_keys.slice(:job_class)
    end
    all_enqueued.reject! { |row| row[:job_class] == 'Que::Scheduler::SchedulerJob' }
    expect(all_enqueued).to eq(to_be_scheduled)
  end

  def expect_itself_enqueued
    itself_jobs = jobs_by_class(Que::Scheduler::SchedulerJob)
    expect(itself_jobs.count).to eq(1)
    hash = itself_jobs.first.to_h
    expect(hash['queue']).to eq('')
    expect(hash['priority']).to eq(0)
    expect(hash['job_class']).to eq('Que::Scheduler::SchedulerJob')
    expect(hash['run_at']).to eq(
      run_time.beginning_of_minute + Que::Scheduler::SchedulerJob::SCHEDULER_FREQUENCY
    )
    expect(hash['args']).to eq(
      [{ 'last_run_time' => run_time.iso8601, 'job_dictionary' => full_dictionary }]
    )
  end
end
