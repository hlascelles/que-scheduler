require "spec_helper"

RSpec.describe Que::Scheduler::SchedulerJob do
  include_context "when job testing"

  let(:run_time) { Time.zone.parse("2017-11-08T13:50:32") }

  around do |example|
    Timecop.freeze(run_time) do
      example.run
    end
  end

  before do
    DbSupport.mock_db_time_now
  end

  def run_scheduler(last_run_time, job_dictionary)
    described_class.enqueue(
      { last_run_time: last_run_time.iso8601, job_dictionary: job_dictionary }
    )
    SyncJobWorker.work_job
    Que::Scheduler::DbSupport.execute(<<~SQL)
      SELECT * FROM que_jobs
      WHERE job_class <> 'Que::Scheduler::SchedulerJob'
      ORDER BY priority, run_at, id
    SQL
  end

  # :reek:UtilityFunction
  def audited_run_times
    Que::Scheduler::DbSupport.execute(
      "SELECT run_at FROM que_scheduler_audit_enqueued ORDER BY run_at"
    ).pluck(:run_at)
  end

  it "uses the latest missed time for a coalesced job and its audit row" do
    jobs = run_scheduler(run_time - 2.hours, %w[HalfHourlyTestJob])
    expected_time = Time.zone.parse("2017-11-08T13:30:00")

    expect(jobs.pluck(:run_at)).to eq([expected_time])
    expect(job_args_from_db_row(jobs.first)).to eq([])
    expect(audited_run_times).to eq([expected_time])
    audit = Que::Scheduler::DbSupport.execute("SELECT * FROM que_scheduler_audit").first
    expect(audit[:executed_at]).to eq(run_time)
  end

  it "preserves each missed event time in the job, arguments and audit" do
    jobs = run_scheduler(run_time - 2.days, %w[DailyTestJob])
    expected_times = [
      Time.zone.parse("2017-11-07T06:10:00"),
      Time.zone.parse("2017-11-08T06:10:00"),
    ]

    expect(jobs.pluck(:run_at)).to eq(expected_times)
    expect(jobs.map { |job| job_args_from_db_row(job) }).to eq(
      expected_times.map { |time| [time.iso8601, "Single arg"] }
    )
    expect(audited_run_times).to eq(expected_times)
  end

  it "orders overdue jobs by scheduled time across schedule entries" do
    Que::Scheduler.configure do |config|
      config.schedule = {
        later: { class: "HalfHourlyTestJob", cron: "45 * * * *", args: ["later"] },
        earlier: { class: "HalfHourlyTestJob", cron: "15 * * * *", args: ["earlier"] },
      }
    end

    jobs = run_scheduler(run_time - 50.minutes, %w[later earlier])

    expect(jobs.map { |job| job_args_from_db_row(job) }).to eq([["earlier"], ["later"]])
    expect(jobs.pluck(:run_at)).to eq(
      [Time.zone.parse("2017-11-08T13:15:00"), Time.zone.parse("2017-11-08T13:45:00")]
    )
  end
end
