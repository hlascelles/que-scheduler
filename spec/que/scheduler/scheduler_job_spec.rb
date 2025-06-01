require "spec_helper"
require "timecop"
require "yaml"
require "active_support/core_ext/numeric/time"

RSpec.describe Que::Scheduler::SchedulerJob do
  include_context "when job testing"

  let(:default_queue) { DbSupport.column_default("que_jobs", "queue").split(":").first[1..-2] }
  let(:default_priority) { DbSupport.column_default("que_jobs", "priority").to_i }
  let(:run_time) { Time.zone.parse("2017-11-08T13:50:32") }
  let(:full_dictionary) { ::Que::Scheduler.schedule.keys }

  describe "RETRY_PROC" do
    it "sets the proc" do
      expect(described_class::RETRY_PROC.call(6)).to eq(1299)
      expect(described_class::RETRY_PROC.call(7)).to eq(2404)
      expect(described_class::RETRY_PROC.call(8)).to eq(3600)
      expect(described_class::RETRY_PROC.call(9)).to eq(3600)
    end
  end

  context "when scheduling" do
    around do |example|
      Timecop.freeze(run_time) do
        example.run
      end
    end

    before do
      DbSupport.mock_db_time_now
    end

    describe "#run" do
      it "runs the state checks" do
        expect(Que::Scheduler::StateChecks).to receive(:check).once
        run_test(nil, [])
      end

      it "enqueues nothing having loaded the dictionary on the first run" do
        run_test(nil, [])
      end

      it "enqueues nothing if it knows about a job, but it is not overdue" do
        run_test(
          {
            last_run_time: (run_time - 15.minutes).iso8601,
            job_dictionary: %w[HalfHourlyTestJob],
          },
          []
        )
      end

      it "enqueues known jobs that are overdue" do
        run_test(
          {
            last_run_time: (run_time - 45.minutes).iso8601,
            job_dictionary: %w[HalfHourlyTestJob],
          },
          [{ job_class: expected_class_in_db(HalfHourlyTestJob).to_s }]
        )
      end

      # Some middlewares can cause an enqueue not to enqueue a job.
      # When the main job fails to self enqueue, we must error.
      it "errors when the enqueue call does not enqueue the #{described_class} job" do
        job = described_class.enqueue
        expect(described_class).to receive(:enqueue).and_return(false)
        expect {
          job.run(nil)
        }.to raise_error(/SchedulerJob could not self-schedule. Has `.enqueue` been monkey patched/)
      end

      def run_test(initial_job_args, to_be_scheduled)
        described_class.enqueue(initial_job_args)
        SyncJobWorker.work_job
        expect_itself_enqueued
        all_enqueued = Que.job_stats.map do |j|
          j.symbolize_keys.slice(:job_class)
        end
        all_enqueued.reject! { |row| row[:job_class] == "Que::Scheduler::SchedulerJob" }
        expect(all_enqueued).to eq(to_be_scheduled)
      end
    end

    describe "#enqueue_required_jobs" do
      def test_enqueued(overdue_dictionary)
        result = Que::Scheduler::EnqueueingCalculator::Result.new(
          missed_jobs: HashSupport.hash_to_enqueues(overdue_dictionary), job_dictionary: []
        )
        described_class.new({}).enqueue_required_jobs(result, [])
      end

      def expect_one_result(args, queue, priority)
        jobs = DbSupport.jobs_by_class(expected_class_in_db(HalfHourlyTestJob))
        expect(jobs.count).to eq(1)
        one_result = jobs.first

        expect_job_args_to_equal(job_args_from_db_row(one_result) || [], args)
        expect(one_result[:queue]).to eq(queue) if handles_queue_name
        expect(one_result[:priority]).to eq(priority)
        expect(one_result[:job_class]).to eq(expected_class_in_db(HalfHourlyTestJob).to_s)
      end

      it "schedules nothing if nothing in the result" do
        test_enqueued([])
        expect(Que.job_stats).to eq([])
      end

      it "schedules one job with no args" do
        test_enqueued([{ job_class: HalfHourlyTestJob }])
        expect_one_result([], default_queue, default_priority)
      end

      it "schedules one job with one String arg" do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: "foo" }])
        expect_one_result(["foo"], default_queue, default_priority)
      end

      it "schedules one job with one Hash arg" do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: { bar: "foo" } }])
        expect_one_result([{ bar: "foo" }], default_queue, default_priority)
      end

      it "schedules one job with one Array arg" do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: %w[foo bar] }])
        expect_one_result(%w[foo bar], default_queue, default_priority)
      end

      it "schedules one job with one String arg and a queue" do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: "foo", queue: "baz" }])
        expect_one_result(["foo"], "baz", default_priority)
      end

      it "schedules one job with one String arg and a priority" do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: "foo", priority: 10 }])
        expect_one_result(["foo"], default_queue, 10)
      end

      it "schedules one job with one Hash arg and a queue" do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: { bar: "foo" }, queue: "baz" }])
        expect_one_result([{ bar: "foo" }], "baz", default_priority)
      end

      it "schedules one job with one Hash arg and a priority" do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: { bar: "foo" }, priority: 10 }])
        expect_one_result([{ bar: "foo" }], default_queue, 10)
      end

      it "schedules one job with one Array arg and a queue" do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: %w[foo bar], queue: "baz" }])
        expect_one_result(%w[foo bar], "baz", default_priority)
      end

      it "schedules one job with one Array arg and a priority" do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: %w[foo bar], priority: 10 }])
        expect_one_result(%w[foo bar], default_queue, 10)
      end

      it "schedules one job with a mixed arg, and a priority, and a queue" do
        test_enqueued(
          [
            {
              job_class: HalfHourlyTestJob,
              args: { baz: 10, array_baz: ["foo"] },
              queue: "bar",
              priority: 10,
            },
          ]
        )
        expect_one_result([{ baz: 10, array_baz: ["foo"] }], "bar", 10)
      end

      # Some middlewares can cause an enqueue not to enqueue a job. For example, an equivalent
      # of resque-solo could decide that the enqueue is not necessary and just short circuit. When
      # this happens we don't want to error, but just log the fact.
      it "handles when the enqueue call does not enqueue a job" do
        null_enqueue_call(HalfHourlyTestJob)
        test_enqueued([{ job_class: HalfHourlyTestJob }])
        expect(Que.job_stats).to eq([])
        qsae = Que::Scheduler::DbSupport.execute("select * from que_scheduler_audit_enqueued")
        expect(qsae.count).to eq(0)
      end
    end
  end

  context "with configuration" do
    # The scheduler job must run at the highest priority, as it must serve the highest common
    # denominator of all schedulable jobs.
    it "runs the scheduler at highest priority" do
      expect(described_class.instance_variable_get(:@priority)).to eq(0)
    end
  end

  def expect_one_itself_job
    itself_jobs = DbSupport.jobs_by_class(Que::Scheduler::SchedulerJob)
    expect(itself_jobs.count).to eq(1)
    itself_jobs.first.to_h
  end

  def expect_itself_enqueued
    hash = expect_one_itself_job
    expect(hash.fetch(:queue)).to eq(Que::Scheduler.configuration.que_scheduler_queue)
    expect(hash.fetch(:priority)).to eq(0)
    expect(hash.fetch(:error_count)).to eq(0)
    expect(hash.fetch(:job_class)).to eq("Que::Scheduler::SchedulerJob")
    expect(hash.fetch(:run_at)).to eq(
      run_time.beginning_of_minute + described_class::SCHEDULER_FREQUENCY
    )
    expect_job_args_to_equal(
      hash[:args], [{ last_run_time: run_time.iso8601, job_dictionary: full_dictionary }]
    )
  end

  def expect_job_args_to_equal(args, to_equal)
    args_sym = JSON.parse(args.to_json, symbolize_names: true)
    # Remove the ActiveJob noise
    if args_sym.is_a?(Array) && args_sym[0].is_a?(Hash)
      args_sym[0] = args_sym[0].except(:_aj_ruby2_keywords)
    end
    expect(args_sym).to eq(to_equal)
  end
end
