require 'spec_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'readme' do
  describe 'README.md' do
    it 'shows the right version in the migration' do
      v = Que::Scheduler::Migrations::MAX_VERSION
      expect(IO.read('README.md')).to include("Que::Scheduler::Migrations.migrate!(version: #{v})")
    end
  end
end
# rubocop:enable RSpec/DescribeClass
