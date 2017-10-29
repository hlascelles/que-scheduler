require 'spec_helper'
require 'active_support/core_ext/numeric/time'

RSpec.describe Que::Scheduler::ScheduleParser do
  QSSP = described_class

  let(:all_keys) do
    %w[
      HalfHourlyTestJob
      WithArgsTestJob
      daily_test_job_specifying_class
      DailyTestJob
      TwiceDailyTestJob
    ]
  end

  it 'should not enqueue anything if not enough time has gone by' do
    run_test('2017-10-08T16:40:32+0100', 1.second, {})
  end

  it 'should enqueue the HalfHourlyTestJob if half an hour has gone by' do
    run_test('2017-10-08T16:40:32+0100', 31.minutes, HalfHourlyTestJob => [[]])
  end

  it 'should enqueue the HalfHourlyTestJob just once if more than an hour has gone by' do
    # Not "unmissable", so, we just schedule the latest
    run_test('2017-10-08T16:40:32+0100', 61.minutes, HalfHourlyTestJob => [[]])
  end

  it 'should enqueue if the run time is exactly the cron time' do
    run_test('2017-10-08T16:59:59+0100', 1.seconds, HalfHourlyTestJob => [[]])
  end

  # This is testing that the fugit cron "next_time" doesn't return the current time if it matches.
  # It truly is the "next" time.
  it 'should not enqueue if the previous run time was exactly the cron time' do
    run_test('2017-10-08T16:00:00+0100', 1.seconds, {})
  end

  it 'should enqueue jobs with args' do
    run_test(
      '2017-10-08T11:39:59+0100',
      2.seconds,
      WithArgsTestJob => [['My Args', 1234, { 'some_hash' => true }]]
    )
  end

  it 'should enqueue jobs that specify the job class as an arg' do
    run_test(
      '2017-10-08T03:09:59+01:00',
      2.seconds,
      SpecifiedByClassTestJob => [[]]
    )
  end

  it 'should enqueue an unmissable job once with date arg if seen to be missed once' do
    run_test(
      '2017-10-08T06:09:59+01:00',
      2.seconds,
      DailyTestJob => [[Time.parse('2017-10-08T06:10:00+01:00')]]
    )
  end

  it 'should enqueue an unmissable job multiple times if missed repeatedly' do
    run_test(
      '2017-10-08T02:09:59+01:00',
      2.days,
      # These are "missable", so only come up once
      HalfHourlyTestJob => [[]],
      WithArgsTestJob => [['My Args', 1234, { 'some_hash' => true }]],
      SpecifiedByClassTestJob => [[]],

      # These are "unmissable", so all their missed schedules are enqueued, with that
      # Time as an argument.
      DailyTestJob => [
        [Time.parse('2017-10-08T06:10:00+01:00')],
        [Time.parse('2017-10-09T06:10:00+01:00')]
      ],
      TwiceDailyTestJob => [
        [Time.parse('2017-10-08T11:10:00+01:00')],
        [Time.parse('2017-10-08T16:10:00+01:00')],
        [Time.parse('2017-10-09T11:10:00+01:00')],
        [Time.parse('2017-10-09T16:10:00+01:00')]
      ]
    )
  end

  def run_test(last_run_time, delay_since_last_scheduler, expect_scheduled, known_jobs = all_keys)
    last_time = Time.parse(last_run_time)
    as_time = last_time + delay_since_last_scheduler
    out = QSSP.parse(Que::Scheduler::SchedulerJob.scheduler_config, as_time, last_time, known_jobs)
    exp = Que::Scheduler::ScheduleParserResult
          .new(expect_scheduled, all_keys, QSSP::SCHEDULER_FREQUENCY)
    expect(out.missed_jobs).to eq(exp.missed_jobs)
    expect(out.schedule_dictionary).to eq(exp.schedule_dictionary)
    expect(out.seconds_until_next_job).to eq(exp.seconds_until_next_job)
  end
end
