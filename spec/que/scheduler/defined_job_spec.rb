require 'spec_helper'

RSpec.describe Que::Scheduler::DefinedJob do
  it 'creates the right job defaults' do
    job = described_class.new(
      name: 'HalfHourlyTestJob',
      job_class: HalfHourlyTestJob,
      cron: '0,30 * * * *'
    )
    expected = {
      name: 'HalfHourlyTestJob',
      job_class: HalfHourlyTestJob,
      cron: Fugit::Cron.new('0,30 * * * *'),
      priority: nil,
      args: nil,
      queue: nil,
      unmissable: false
    }
    expect(job.to_h).to eq(expected)
  end

  describe '#next_run_time' do
    let(:job) {
      described_class.new(
        name: 'HalfHourlyTestJob',
        job_class: HalfHourlyTestJob,
        cron: '14 17 * * *'
      )
    }

    def expect_time(from, to, exp)
      expect(job.next_run_time(Time.zone.parse(from), Time.zone.parse(to))).to eq(exp)
    end

    it "calculates the next run time over a day" do
      expect_time('2017-10-08T06:10:00', '2017-10-09T06:10:00', Time.zone.parse('2017-10-08T17:14:00'))
    end

    it "calculates the next run time under a day" do
      expect_time('2017-10-08T06:10:00', '2017-10-08T21:10:00', Time.zone.parse('2017-10-08T17:14:00'))
    end

    it "calculates the next run starting from exactly cron time" do
      expect_time('2017-10-08T17:14:00', '2017-10-09T21:10:00', Time.zone.parse('2017-10-09T17:14:00'))
    end

    it "calculates the next run when it is after the closing time" do
      expect_time('2017-10-08T06:14:00', '2017-10-08T10:10:00', nil)
    end
  end
end
