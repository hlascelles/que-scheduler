require 'spec_helper'

RSpec.describe Que::Scheduler::Schedule do
  describe '.schedule' do
    it 'allows access via ::Que::Scheduler.schedule' do
      expect(described_class).to receive(:schedule)
      Que::Scheduler.schedule
    end

    it 'loads the test schedule' do
      expect(Que::Scheduler.schedule.size).to eq(6)
    end
  end

  describe '.from_file' do
    it 'loads the given file' do
      result = described_class.from_file('spec/config/que_schedule2.yml')
      expect(result.size).to eq(1)
      expect(result.keys.first).to eq('test_schedule_2')
    end
  end
end
