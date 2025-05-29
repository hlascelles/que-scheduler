require "spec_helper"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "integration tests" do
  def run_integration_test(dir, cmd)
    env = "QUE_VERSION=#{Que::Scheduler::VersionSupport.que_version} "
    loaded_specs = Gem.loaded_specs
    if loaded_specs.key?("activerecord")
      env += "ACTIVE_RECORD_VERSION=#{loaded_specs['activerecord'].version} "
    end
    env += "RAILS_VERSION=#{loaded_specs['rails'].version} " if loaded_specs.key?("rails")

    Bundler.with_unbundled_env do
      Dir.chdir("spec/integration/#{dir}") do # rubocop:disable ThreadSafety/DirChdir
        run = "#{env} #{cmd}"
        puts "Running: #{run}"
        result = system(run)
        raise "Integration test failed" unless result
      end
    end
  end

  describe "no rails" do
    it "enqueues and runs a simple job" do
      run_integration_test("no_rails", "ruby simple_test.rb")
    end

    it "enqueues and runs the QueSchedulerAuditClearDownJob" do
      run_integration_test("no_rails", "ruby cleardown_job_test.rb")
    end
  end
end
# rubocop:enable RSpec/DescribeClass
