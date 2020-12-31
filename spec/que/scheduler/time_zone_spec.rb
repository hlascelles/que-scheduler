require "spec_helper"

RSpec.describe Que::Scheduler::TimeZone do
  include_context "when checking we cannot use code", "Time.zone", "time_zone.rb"

  before(:each) do
    described_class.instance_variable_set("@time_zone", nil)
  end

  describe ".time_zone" do
    it "returns the Time.zone value" do
      expect(described_class.time_zone).to eq(Time.zone)
    end

    it "fails if the config and Time.zone are both set" do
      Que::Scheduler.configure do |config|
        config.time_zone = "Europe/London"
        expect {
          described_class.time_zone
        }.to raise_error(Que::Scheduler::TimeZone::BOTH_CONFIG_AND_TIME_DOT_ZONE_SET)
      end
    end

    it "uses the que-scheduler config if Time.zone is not set" do
      Que::Scheduler.configure do |config|
        config.time_zone = "Europe/Paris"
      end
      expect(Time).to receive(:zone).and_return(nil)
      expect(ActiveSupport::TimeZone).to receive(:new).and_call_original
      expect(described_class.time_zone.name).to eq("Europe/Paris")
    end

    it "errors if the que-scheduler config is not known" do
      Que::Scheduler.configure do |config|
        config.time_zone = "Europe/Edinburgh"
      end
      expect(Time).to receive(:zone).and_return(nil)
      expect(ActiveSupport::TimeZone).to receive(:new).and_call_original
      expect {
        described_class.time_zone
      }.to raise_error(Que::Scheduler::TimeZone::TIME_ZONE_CONFIG_IS_NOT_VALID)
    end
  end
end
