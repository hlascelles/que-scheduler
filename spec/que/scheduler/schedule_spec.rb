require "spec_helper"

RSpec.describe Que::Scheduler::Schedule do
  let(:new_config_yaml) {
    '
    SpecifiedByClassTestJob:
      cron: "02 11 * * *"
      args:
        - First
        - 1234
        - some_hash: true
    '
  }

  describe ".schedule" do
    it "allows access via ::Que::Scheduler.schedule" do
      expect(described_class).to receive(:schedule)
      Que::Scheduler.schedule
    end

    it "loads the test schedule" do
      entries = YAML.safe_load(File.read("spec/config/que_schedule.yml"))
      expect(entries.keys.count).to be > 0
      expect(Que::Scheduler.schedule.keys).to eq(entries.keys)
    end

    it "loads the schedule from an ENV" do
      Que::Scheduler.configure do |config|
        config.schedule_location = "spec/config/que_schedule2.yml"
      end
      entries = YAML.safe_load(File.read("spec/config/que_schedule2.yml"))
      expect(Que::Scheduler.schedule.keys).to eq(entries.keys)
    end

    it "loads the schedule from a hash" do
      Que::Scheduler.configure do |config|
        config.schedule = YAML.safe_load(new_config_yaml)
      end
      expect(Que::Scheduler.schedule.keys).to eq(YAML.safe_load(new_config_yaml).keys)
      job_config = Que::Scheduler.schedule["SpecifiedByClassTestJob"]
      expect(job_config[:name]).to eq("SpecifiedByClassTestJob")
      expect(job_config[:args_array]).to eq(["First", 1234, { "some_hash" => true }])
    end

    it "loads the schedule with all key types" do
      Que::Scheduler.configure do |config|
        config.schedule = {
          # Symbol
          AsSymbolSpecifiedByClassTestJob: {
            class: :SpecifiedByClassTestJob,
            cron: "01 * * * *",
          },
          # String
          "AsStringSpecifiedByClassTestJob" => {
            class: "SpecifiedByClassTestJob",
            cron: "02 * * * *",
          },
          # Class
          SpecifiedByClassTestJob => {
            cron: "03 * * * *",
          },
        }
      end
      expect(Que::Scheduler.schedule.keys).to eq(
        %w[
          AsSymbolSpecifiedByClassTestJob
          AsStringSpecifiedByClassTestJob
          SpecifiedByClassTestJob
        ]
      )
      expect(Que::Scheduler.schedule.values.map(&:job_class)).to eq(
        [SpecifiedByClassTestJob, SpecifiedByClassTestJob, SpecifiedByClassTestJob]
      )
    end

    it "errors if the schedule hash is not set and the file is not present" do
      Que::Scheduler.configure do |config|
        config.schedule_location = "spec/config/not_here.yml"
        config.schedule = nil
      end
      expect {
        Que::Scheduler.schedule
      }.to raise_error(/No que-scheduler config set/)
    end
  end

  describe ".from_file" do
    it "loads the given file" do
      result = described_class.from_file("spec/config/que_schedule2.yml")
      expect(result.size).to eq(1)
      expect(result.keys.first).to eq("test_schedule_2")
    end
  end

  describe "loading args" do
    let(:valid_options) {
      {
        cron: "14 17 * * *",
      }
    }

    def test_args(options, expect_args_array)
      defined_job = described_class.hash_item_to_defined_job(
        "HalfHourlyTestJob", options.stringify_keys
      )
      expect(defined_job.args_array).to eq(expect_args_array)
    end

    it "stores args correctly if it is an array" do
      test_args(valid_options.merge(args: ["foo"]), ["foo"])
    end

    it 'stores args correctly if it is a value that is "null"' do
      test_args(valid_options.merge(args: nil), [nil])
    end

    it 'stores args correctly if it is an array with a "null"' do
      test_args(valid_options.merge(args: [nil]), [nil])
    end

    it "stores args correctly if they are missing" do
      valid_options.delete(:args)
      test_args(valid_options, [])
    end

    it "stores args correctly if they are a hash" do
      test_args(valid_options.merge(args: { "baz" => "bar" }), [{ "baz" => "bar" }])
    end
  end
end
