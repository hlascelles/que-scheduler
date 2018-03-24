require 'spec_helper'
require 'active_record'
require 'sequel'

::DB = Sequel.sqlite
::ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
QSAO = ::Que::Scheduler::Adapters::Orm

RSpec.describe QSAO do
  {
    QSAO::ActiveRecordAdapter => ::ActiveRecord::Base,
    QSAO::SequelAdapter => ::DB
  }.each do |adapters, connection|
    describe adapters do
      let(:adapter) { described_class.new }

      describe '#count_schedulers' do
        it 'finds the right number of rows' do
          adapter.ddl('CREATE TABLE que_jobs (job_class VARCHAR(255));')
          adapter.ddl("INSERT INTO que_jobs values ('SomeJob');")
          expect(adapter.count_schedulers).to eq(0)
          adapter.ddl("INSERT INTO que_jobs values ('Que::Scheduler::SchedulerJob');")
          expect(adapter.count_schedulers).to eq(1)
          adapter.ddl("INSERT INTO que_jobs values ('Que::Scheduler::SchedulerJob');")
          expect(adapter.count_schedulers).to eq(2)
        end
      end

      describe '#transaction' do
        it 'starts a transaction correctly' do
          expect(connection).to receive(:transaction) do |_, &block|
            expect(block.call).to eq('test')
          end
          adapter.transaction do
            'test'
          end
        end
      end

      describe '#now' do
        it 'returns the value from the DB' do
          expect(adapter).to receive(:dml).with('SELECT now()').and_return(
            [{ 'now' => '2018-03-24 10:18:29.079874+01' }]
          )
          # Check the time parsing handles timezones by expecting a different time in a different
          # timezone.
          expect(adapter.now).to eq(Time.zone.parse('2018-03-24 09:18:29.079874+00'))
        end
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
      expect(orm.class).to eq(QSAO::ActiveRecordAdapter)
    end

    it 'returns the correct class for Sequel' do
      expect(Gem.loaded_specs).to receive(:has_key?).with('activerecord').and_return(false)
      expect(Gem.loaded_specs).to receive(:has_key?).with('sequel').and_return(true)
      orm = described_class.instance
      expect(orm.class).to eq(QSAO::SequelAdapter)
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
