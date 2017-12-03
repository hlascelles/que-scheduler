require 'spec_helper'

RSpec.describe Que::Scheduler::ScheduleParser do
  # This test makes sure the old way of using "unmissable: true" is migrated correctly.
  it 'caters for the old unmissable key style' do
    expect(described_class.send(:schedule_type, 'unmissable' => true))
      .to eq(Que::Scheduler::DefinedJob::SCHEDULE_TYPE_EVERY_EVENT)
  end
end
