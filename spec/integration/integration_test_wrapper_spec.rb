require "spec_helper"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "integration tests" do
  def run_integration_test(cmd)
    Bundler.with_clean_env do
      Dir.chdir("spec/integration/no_rails") do
        result = system(cmd)
        raise "Integration test failed" unless result
      end
    end
  end

  it "enqueues and runs a simple job" do
    run_integration_test(
      "QUE_VERSION=#{Que::Scheduler::VersionSupport.que_version} ruby simple_test.rb"
    )
  end
end
# rubocop:enable RSpec/DescribeClass
