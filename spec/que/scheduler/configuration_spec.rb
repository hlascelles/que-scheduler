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
end
