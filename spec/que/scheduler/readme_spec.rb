require "spec_helper"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "readme" do
  describe "README.md" do
    it "shows the right version in the migration examples" do
      readme = IO.read("README.md")
      found_versions = readme.scan(/version: (\d)/).flatten.uniq
      expect(found_versions).to eq([Que::Scheduler::Migrations::MAX_VERSION.to_s])
    end
  end
end
# rubocop:enable RSpec/DescribeClass
