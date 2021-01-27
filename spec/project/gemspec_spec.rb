require "spec_helper"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "gemspec" do
  it "consistently targets a ruby version" do
    ver_regex = '[0-9]+\.[0-9]+'
    from_rubocop = YAML.load_file(".rubocop.yml").fetch("AllCops").fetch("TargetRubyVersion").to_s
    from_gem_spec = IO.read("que-scheduler.gemspec")
                      .match(/.*required_ruby_version.*(#{ver_regex})/)
                      .captures.first.to_s
    from_ci = IO.read(".gitlab-ci.yml").match(/.* ruby:(#{ver_regex})/).captures.first.to_s

    expect(from_rubocop).to eq(from_gem_spec)
    expect(from_rubocop).to eq(from_ci)
  end
end
# rubocop:enable RSpec/DescribeClass
