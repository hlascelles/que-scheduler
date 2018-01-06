require 'spec_helper'

RSpec.describe Que::Scheduler::Engine do
  # This test resets the schedule singleton, then checks that starting Rails triggers a
  # parse of the schedule. This ensures a fast fail during startup if the config file is invalid.
  it 'loads the schedule file in an initialiser' do
    expect(::Que::Scheduler::DefinedJob).to receive(:defined_jobs).once.and_call_original
    Combustion.initialize!
  end
end
