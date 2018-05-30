require 'spec_helper'

RSpec.describe Que::Scheduler::Db do
  describe '.count_schedulers' do
    it 'returns the right result' do
      expect(described_class.count_schedulers).to eq(0)
      ::Que::Scheduler::SchedulerJob.enqueue
      expect(described_class.count_schedulers).to eq(1)
      ::Que::Scheduler::SchedulerJob.enqueue
      expect(described_class.count_schedulers).to eq(2)
    end
  end

  describe '.now' do
    it 'returns the time' do
      expect(Que).to receive(:execute).with(described_class::NOW_SQL).and_return([{ foo: :bar }])
      expect(described_class.now).to eq(:bar)
    end
  end

  # We have users running both ActiveRecord and Sequel. We should not rely on either of them in
  # runtime code except when specified in an adapter.
  describe 'ORM usage' do
    def check(str)
      Dir.glob('lib/**/*').each do |file|
        if File.file?(file) && !file.end_with?('db.rb')
          expect(File.open(file).grep(/#{str}/)).to be_empty
        end
      end
    end

    it 'ActiveRecord is not used explicitly' do
      check('ActiveRecord')
    end

    it 'Sequel is not used explicitly' do
      check('Sequel')
    end

    # describe '.transaction' do
    #   it 'returns the time' do
    #     expect(Que).to receive(:execute).with(described_class::NOW_SQL).and_return([{ foo: :bar }])
    #     expect(described_class.now).to eq(:bar)
    #   end
    # end

    [::ActiveRecord::Base, ::Que].each do |orm|
      context "using orm #{orm}" do
        include_context('roundtrip tester')

        it 'enqueues known jobs successfully' do
          ::Que::Scheduler::Db.transaction_adapter = orm
          expect(orm).to receive(:transaction).twice.and_call_original
          run_test(
            {
              last_run_time: (run_time - 45.minutes).iso8601,
              job_dictionary: %w[HalfHourlyTestJob],
            },
            [{ job_class: 'HalfHourlyTestJob' }]
          )
          # Reset the DB after the Que adapter as it causes conflicts with rspec's transactions
          setup_db if orm == ::Que
          ::Que::Scheduler::Db.transaction_adapter = nil
        end
      end
    end
  end
end
