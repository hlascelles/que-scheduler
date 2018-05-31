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

    describe '.transaction' do
      after(:all) do
        # The DB needs setting up again after raw Que as the main tests run under ActiveRecord
        setup_db
      end

      [::ActiveRecord::Base, ::Que].each do |orm|
        it "using the #{orm} adapter" do
          expect(described_class)
            .to receive(:use_active_record_transaction_adapter).and_return(orm != ::Que)
          expect(orm).to receive(:transaction).once.and_call_original

          begin
            ::Que::Scheduler::Db.transaction do
              ::Que::Scheduler::SchedulerJob.enqueue
              expect(jobs_by_class(Que::Scheduler::SchedulerJob).count).to eq(1)
              raise 'Some exception in a transaction'
            end
          rescue RuntimeError
            # Check that a rollback has occurred
            expect(jobs_by_class(Que::Scheduler::SchedulerJob).count).to eq(0)
          end
        end
      end
    end
  end
end
