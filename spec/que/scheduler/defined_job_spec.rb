require 'spec_helper'

RSpec.describe Que::Scheduler::DefinedJob do
  describe '#next_run_time' do
    let(:job) do
      described_class.new(
        name: 'HalfHourlyTestJob',
        job_class: HalfHourlyTestJob,
        cron: '14 17 * * *'
      )
    end

    def expect_time(from, to, exp)
      expected_time = exp ? Time.zone.parse(exp) : nil
      expect(job.next_run_time(Time.zone.parse(from), Time.zone.parse(to))).to eq(expected_time)
    end

    it 'calculates the next run time over a day' do
      expect_time('2017-10-08T06:10:00', '2017-10-09T06:10:00', '2017-10-08T17:14:00')
    end

    it 'calculates the next run time under a day' do
      expect_time('2017-10-08T06:10:00', '2017-10-08T21:10:00', '2017-10-08T17:14:00')
    end

    it 'calculates the next run starting from exactly cron time' do
      expect_time('2017-10-08T17:14:00', '2017-10-09T21:10:00', '2017-10-09T17:14:00')
    end

    it 'calculates the next run when it is after the closing time' do
      expect_time('2017-10-08T06:14:00', '2017-10-08T10:10:00', nil)
    end
  end

  describe 'validations' do
    it 'checks the cron is valid' do
      expect do
        described_class.new(
          name: 'HalfHourlyTestJob',
          job_class: HalfHourlyTestJob,
          cron: 'foo 17 * * *'
        )
      end.to raise_error(/Invalid cron 'foo 17 \* \* \*' in que-scheduler config/)
    end

    it 'checks the queue is a string' do
      expect do
        described_class.new(
          name: 'HalfHourlyTestJob',
          job_class: HalfHourlyTestJob,
          queue: 3_214_214
        )
      end.to raise_error(/Invalid queue '3214214' in que-scheduler config/)
    end

    it 'checks the priority is an integer' do
      expect do
        described_class.new(
          name: 'HalfHourlyTestJob',
          job_class: HalfHourlyTestJob,
          priority: 'foo'
        )
      end.to raise_error(/Invalid priority 'foo' in que-scheduler config/)
    end
  end
end
