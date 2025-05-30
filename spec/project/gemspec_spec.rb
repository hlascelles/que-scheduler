require "spec_helper"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "gemspec" do
  it "consistently targets a ruby version" do
    from_rubocop =
      YAML.load_file(".rubocop.yml").fetch("AllCops").fetch("TargetRubyVersion").to_s
    from_ci = YAML.load_file(".github/workflows/specs.yml")
    ci_rubies = from_ci.dig("jobs", "specs", "strategy", "matrix", "ruby")

    expect(from_rubocop).to eq(ci_rubies.first.to_s)
  end
end
# rubocop:enable RSpec/DescribeClass
