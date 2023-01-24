require "spec_helper"

RSpec.describe Que::Scheduler::Configuration do
  describe ".configure" do
    it "defaults the schedule_location to the right value" do
      Que::Scheduler.apply_defaults
      expect(Que::Scheduler.configuration.schedule_location).to eq("config/que_schedule.yml")
    end

    it "reads the schedule_location from the QUE_SCHEDULER_CONFIG_LOCATION ENV" do
      ClimateControl.modify(QUE_SCHEDULER_CONFIG_LOCATION: "baz.yml") do
        Que::Scheduler.apply_defaults
      end
      expect(Que::Scheduler.configuration.schedule_location).to eq("baz.yml")
    end

    it "defaults the queue name to the que default" do
      Que::Scheduler.apply_defaults
      expect(Que::Scheduler.configuration.que_scheduler_queue)
        .to eq(Que::Scheduler::VersionSupport.default_scheduler_queue)
    end

    it "reads the queue name from the QUE_SCHEDULER_QUEUE ENV" do
      ClimateControl.modify(QUE_SCHEDULER_QUEUE: "foo") do
        Que::Scheduler.apply_defaults
      end
      expect(Que::Scheduler.configuration.que_scheduler_queue).to eq("foo")
    end

    it "defaults the transaction_adapter to the que default" do
      Que::Scheduler.apply_defaults
      expect(Que::Scheduler.configuration.transaction_adapter).to eq(::Que.method(:transaction))
    end
  end

  describe ".apply_defaults" do
    it "sets the schedule_location to the default" do
      Que::Scheduler.apply_defaults
      expect(Que::Scheduler.configuration.schedule_location).to eq("config/que_schedule.yml")
    end

    it "sets the que_scheduler_queue to the default" do
      Que::Scheduler.apply_defaults
      expect(Que::Scheduler.configuration.que_scheduler_queue)
        .to eq(Que::Scheduler::VersionSupport.default_scheduler_queue)
    end

    it "sets the transaction_adapter to the default" do
      Que::Scheduler.apply_defaults
      expect(Que::Scheduler.configuration.transaction_adapter).to eq(::Que.method(:transaction))
    end

    it "sets the schedule to nil" do
      Que::Scheduler.apply_defaults
      expect(Que::Scheduler.configuration.schedule).to be_nil
    end

    it "sets the time_zone to nil" do
      Que::Scheduler.apply_defaults
      expect(Que::Scheduler.configuration.time_zone).to be_nil
    end

    it "sets the schedule_location to the QUE_SCHEDULER_CONFIG_LOCATION ENV" do
      ClimateControl.modify(QUE_SCHEDULER_CONFIG_LOCATION: "baz.yml") do
        Que::Scheduler.apply_defaults
      end
      expect(Que::Scheduler.configuration.schedule_location).to eq("baz.yml")
    end
  end
end
