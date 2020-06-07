require 'spec_helper'

RSpec.describe Que::Scheduler::Schedule do
  describe '.schedule' do
    it 'allows access via ::Que::Scheduler.schedule' do
      expect(described_class).to receive(:schedule)
      Que::Scheduler.schedule
    end

    it 'loads the test schedule' do
      entries = YAML.safe_load(IO.read('spec/config/que_schedule.yml')).keys
      expect(entries.count).to be > 0
      expect(Que::Scheduler.schedule.size).to eq(entries.count)
    end
  end

  describe '.from_file' do
    it 'loads the given file' do
      result = described_class.from_file('spec/config/que_schedule2.yml')
      expect(result.size).to eq(1)
      expect(result.keys.first).to eq('test_schedule_2')
    end
  end

  describe 'loading args' do
    let(:valid_options) {
      {
        cron: '14 17 * * *',
      }
    }

    def test_args(options, expect_args_array)
      defined_job = described_class.hash_item_to_defined_job(
        'HalfHourlyTestJob', options.stringify_keys
      )
      expect(defined_job.args_array).to eq(expect_args_array)
    end

    it 'stores args correctly if it is an array' do
      test_args(valid_options.merge(args: ['foo']), ['foo'])
    end

    it 'stores args correctly if it is a value that is "null"' do
      test_args(valid_options.merge(args: nil), [nil])
    end

    it 'stores args correctly if it is an array with a "null"' do
      test_args(valid_options.merge(args: [nil]), [nil])
    end

    it 'stores args correctly if they are missing' do
      valid_options.delete(:args)
      test_args(valid_options, [])
    end

    it 'stores args correctly if they are a hash' do
      test_args(valid_options.merge(args: { 'baz' => 'bar' }), [{ 'baz' => 'bar' }])
    end
  end
end
