require 'spec_helper'

RSpec.describe Que::Scheduler::VersionSupport do
  describe '.set_priority' do
    it 'sets the priority' do
      obj = double
      described_class.set_priority(obj, 3)
      expect(obj.instance_variable_get('@priority')).to eq(3)
    end
  end

  describe '.job_attributes' do
    it 'retrieves the job attributes in a consistent manner' do
      job = Que::Scheduler::SchedulerJob.enqueue
      expected = hash_including(
        args: [],
        error_count: 0,
        job_class: 'Que::Scheduler::SchedulerJob',
        last_error: nil,
        priority: 0,
        queue: ''
      )
      attrs = described_class.job_attributes(job)
      expect(attrs).to match(expected)
      # Keys changed from strings to symbols with que 1.0
      # We consolidate on symbols.
      attrs.each_key do |key|
        expect(key).to be_a(Symbol)
      end
      expect(attrs.fetch(:job_id)).to be_a(Integer)
      expect(attrs.fetch(:run_at)).to be_a(Time)
    end
  end

  describe '.default_scheduler_queue' do
    it 'returns the queue name' do
      expect(described_class.default_scheduler_queue).to eq('')
    end
  end
end
