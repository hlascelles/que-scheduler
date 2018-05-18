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

  # We hvae users running both ActiveRecord and Sequel. We should not refer to either of them in
  # runtime code.
  describe 'ORM usage' do
    def check(str)
      Dir.glob('lib/**/*').each do |file|
        expect(File.open(file).grep(/#{str}/)).to be_empty if File.file?(file)
      end
    end

    it 'ActiveRecord is not used explicitly' do
      check('ActiveRecord')
    end

    it 'Sequel is not used explicitly' do
      check('Sequel')
    end
  end
end
