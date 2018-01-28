require 'spec_helper'
require 'active_record'
require 'sequel'

::DB = Sequel.sqlite
::ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

RSpec.describe ::Que::Scheduler::Adapters::Orm do
  context 'adapters' do
    def perform_adapter_count_checks
      adapter.ddl('CREATE TABLE que_jobs (job_class VARCHAR(255));')
      adapter.ddl("INSERT INTO que_jobs values ('SomeJob');")
      expect(adapter.count_schedulers).to eq(0)
      adapter.ddl("INSERT INTO que_jobs values ('Que::Scheduler::SchedulerJob');")
      expect(adapter.count_schedulers).to eq(1)
      adapter.ddl("INSERT INTO que_jobs values ('Que::Scheduler::SchedulerJob');")
      expect(adapter.count_schedulers).to eq(2)
    end

    def perform_adapter_transaction_check(underlying_orm)
      expect(underlying_orm).to receive(:transaction) do |_, &block|
        expect(block.call).to eq('test')
      end
      adapter.transaction do
        'test'
      end
    end

    let(:adapter) { described_class.new }

    describe ::Que::Scheduler::Adapters::Orm::ActiveRecordAdapter do
      it 'executes the correct SQL to count rows' do
        perform_adapter_count_checks
      end

      it 'performs an action in a transaction' do
        perform_adapter_transaction_check(::ActiveRecord::Base)
      end
    end

    describe ::Que::Scheduler::Adapters::Orm::SequelAdapter do
      it 'executes the correct SQL' do
        perform_adapter_count_checks
      end

      it 'performs an action in a transaction' do
        perform_adapter_transaction_check(::DB)
      end
    end
  end

  describe '.instance' do
    before(:each) do
      described_class.instance = nil
    end

    it 'returns the correct class for ActiveRecord' do
      expect(Gem.loaded_specs).to receive(:has_key?).with('activerecord').and_return(true)
      orm = described_class.instance
      expect(orm.class).to eq(::Que::Scheduler::Adapters::Orm::ActiveRecordAdapter)
    end

    it 'returns the correct class for Sequel' do
      expect(Gem.loaded_specs).to receive(:has_key?).with('activerecord').and_return(false)
      expect(Gem.loaded_specs).to receive(:has_key?).with('sequel').and_return(true)
      orm = described_class.instance
      expect(orm.class).to eq(::Que::Scheduler::Adapters::Orm::SequelAdapter)
    end

    it 'errors for no orm' do
      %w[activerecord sequel].each do |gem|
        expect(Gem.loaded_specs).to receive(:has_key?).with(gem).and_return(false)
      end
      expect do
        described_class.instance
      end.to raise_error(/No known ORM adapter is available for que-scheduler/)
    end
  end
end
