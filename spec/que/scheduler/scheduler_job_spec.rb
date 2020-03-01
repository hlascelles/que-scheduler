require 'spec_helper'
require 'timecop'
require 'yaml'
require 'active_support/core_ext/numeric/time'

RSpec.describe Que::Scheduler::SchedulerJob do
  QS = Que::Scheduler
  PARSER = QS::EnqueueingCalculator
  RESULT = QS::EnqueueingCalculator::Result
  let(:default_queue) { DbSupport.column_default('que_jobs', 'queue').split(':').first[1..-2] }
  let(:default_priority) { DbSupport.column_default('que_jobs', 'priority').to_i }
  let(:run_time) { Time.zone.parse('2017-11-08T13:50:32') }
  let(:full_dictionary) { ::Que::Scheduler.schedule.keys }

  it "prove that ActiveJob doesn't support Que queue names correctly" do
    TestActiveJob.set(queue: 'foo', queue_name: 'foo').perform_later
    jobs = DbSupport.jobs_by_class(ActiveJob::QueueAdapters::QueAdapter::JobWrapper)
    expect(jobs.first.fetch(:queue)).to eq('foo')
  end

  context 'scheduling' do
    around(:each) do |example|
      Timecop.freeze(run_time) do
        example.run
      end
    end

    before(:each) do
      DbSupport.mock_db_time_now
    end

    describe '#run' do
      it 'runs the state checks' do
        expect(Que::Scheduler::StateChecks).to receive(:check).once
        run_test(nil, [])
      end

      it 'enqueues nothing having loaded the dictionary on the first run' do
        run_test(nil, [])
      end

      it 'enqueues nothing if it knows about a job, but it is not overdue' do
        run_test(
          {
            last_run_time: (run_time - 15.minutes).iso8601,
            job_dictionary: %w[HalfHourlyTestJob],
          },
          []
        )
      end

      it 'enqueues known jobs that are overdue' do
        run_test(
          {
            last_run_time: (run_time - 45.minutes).iso8601,
            job_dictionary: %w[HalfHourlyTestJob],
          },
          [{ job_class: 'HalfHourlyTestJob' }]
        )
      end

      # Some middlewares can cause an enqueue not to enqueue a job.
      # When the main job fails to self enqueue, we must error.
      it "errors when the enqueue call does not enqueue the #{described_class} job" do
        job = described_class.enqueue
        expect(described_class).to receive(:enqueue).and_return(false)
        expect_any_instance_of(::Que::Job).to receive(:handle_error).once.and_call_original
        DbSupport.work_job(job)

        # The job will have been re-enqueued, not by itself during normal operation, but by the
        # standard que job error retry semantics.
        hash = expect_one_itself_job
        expect(hash.fetch(:error_count)).to eq(1)
      end

      def run_test(initial_job_args, to_be_scheduled)
        job = described_class.enqueue(initial_job_args)
        DbSupport.work_job(job)
        expect_itself_enqueued
        all_enqueued = Que.job_stats.map do |j|
          j.symbolize_keys.slice(:job_class)
        end
        all_enqueued.reject! { |row| row[:job_class] == 'Que::Scheduler::SchedulerJob' }
        expect(all_enqueued).to eq(to_be_scheduled)
      end
    end

    {
      HalfHourlyTestJob => [:enqueue, HalfHourlyTestJob],
      TestActiveJob => [:perform_later, ActiveJob::QueueAdapters::QueAdapter::JobWrapper],
    }.each do |job_class, (enqueue_method, enqueued_job_class)|
      describe "#enqueue_required_jobs with #{job_class}" do
        let(:enqueued_job_class) { enqueued_job_class }
        let(:enqueue_method) { enqueue_method }
        let(:job_class) { job_class }

        def test_enqueued(overdue_dictionary)
          result = RESULT.new(
            missed_jobs: HashSupport.hash_to_enqueues(overdue_dictionary), job_dictionary: []
          )
          described_class.new({}).enqueue_required_jobs(result, [])
        end

        def job_args(job_row)
          if enqueue_method == :enqueue
            job_row[:args]
          else
            # ActiveJob args are held in a wrapper
            job_row[:args].first['arguments'].each do |arg|
              arg.delete('_aj_symbol_keys') if arg.is_a?(Hash)
            end
          end
        end

        def null_enqueue_call
          if enqueue_method == :enqueue
            expect(job_class).to receive(enqueue_method).and_return(false)
          else
            expect_any_instance_of(ActiveJob::ConfiguredJob)
              .to receive(enqueue_method).and_return(false)
          end
        end

        def expect_one_result(args, queue, priority)
          jobs = DbSupport.jobs_by_class(enqueued_job_class)
          expect(jobs.count).to eq(1)
          one_result = jobs.first

          expect_job_args_to_equal(job_args(one_result) || [], args)
          expect(one_result[:queue]).to eq(queue)
          expect(one_result[:priority]).to eq(priority)
          expect(one_result[:job_class]).to eq(enqueued_job_class.to_s)
        end

        it 'schedules nothing if nothing in the result' do
          test_enqueued([])
          expect(Que.job_stats).to eq([])
        end

        it 'schedules one job with no args' do
          test_enqueued([{ job_class: job_class }])
          expect_one_result([], default_queue, default_priority)
        end

        it 'schedules one job with one String arg' do
          test_enqueued([{ job_class: job_class, args: 'foo' }])
          expect_one_result(['foo'], default_queue, default_priority)
        end

        it 'schedules one job with one Hash arg' do
          test_enqueued([{ job_class: job_class, args: { bar: 'foo' } }])
          expect_one_result([{ bar: 'foo' }], default_queue, default_priority)
        end

        it 'schedules one job with one Array arg' do
          test_enqueued([{ job_class: job_class, args: %w[foo bar] }])
          expect_one_result(%w[foo bar], default_queue, default_priority)
        end

        it 'schedules one job with one String arg and a queue' do
          test_enqueued([{ job_class: job_class, args: 'foo', queue: 'baz' }])
          expect_one_result(['foo'], 'baz', default_priority)
        end

        it 'schedules one job with one String arg and a priority' do
          test_enqueued([{ job_class: job_class, args: 'foo', priority: 10 }])
          expect_one_result(['foo'], default_queue, 10)
        end

        it 'schedules one job with one Hash arg and a queue' do
          test_enqueued([{ job_class: job_class, args: { bar: 'foo' }, queue: 'baz' }])
          expect_one_result([{ bar: 'foo' }], 'baz', default_priority)
        end

        it 'schedules one job with one Hash arg and a priority' do
          test_enqueued([{ job_class: job_class, args: { bar: 'foo' }, priority: 10 }])
          expect_one_result([{ bar: 'foo' }], default_queue, 10)
        end

        it 'schedules one job with one Array arg and a queue' do
          test_enqueued([{ job_class: job_class, args: %w[foo bar], queue: 'baz' }])
          expect_one_result(%w[foo bar], 'baz', default_priority)
        end

        it 'schedules one job with one Array arg and a priority' do
          test_enqueued([{ job_class: job_class, args: %w[foo bar], priority: 10 }])
          expect_one_result(%w[foo bar], default_queue, 10)
        end

        it 'schedules one job with a mixed arg, and a priority, and a queue' do
          test_enqueued(
            [
              {
                job_class: job_class,
                args: { baz: 10, array_baz: ['foo'] },
                queue: 'bar',
                priority: 10,
              },
            ]
          )
          expect_one_result([{ baz: 10, array_baz: ['foo'] }], 'bar', 10)
        end

        # Some middlewares can cause an enqueue not to enqueue a job. For example, an equivalent
        # of resque-solo could decide that the enqueue is not necessary and just short circuit. When
        # this happens we don't want to error, but just log the fact.
        it 'handles when the enqueue call does not enqueue a job' do
          null_enqueue_call
          test_enqueued([{ job_class: job_class }])
          expect(Que.job_stats).to eq([])
          qsa = Que::Scheduler::VersionSupport.execute('select * from que_scheduler_audit_enqueued')
          expect(qsa.count).to eq(0)
        end
      end
    end
  end

  context 'configuration' do
    # The scheduler job must run at the highest priority, as it must serve the highest common
    # denominator of all schedulable jobs.
    it 'should run the scheduler at highest priority' do
      expect(described_class.instance_variable_get('@priority')).to eq(0)
    end
  end

  def expect_one_itself_job
    itself_jobs = DbSupport.jobs_by_class(QS::SchedulerJob)
    expect(itself_jobs.count).to eq(1)
    itself_jobs.first.to_h
  end

  def expect_itself_enqueued
    hash = expect_one_itself_job
    expect(hash.fetch(:queue)).to eq(Que::Scheduler.configuration.que_scheduler_queue)
    expect(hash.fetch(:priority)).to eq(0)
    expect(hash.fetch(:error_count)).to eq(0)
    expect(hash.fetch(:job_class)).to eq('Que::Scheduler::SchedulerJob')
    expect(hash.fetch(:run_at)).to eq(
      run_time.beginning_of_minute + described_class::SCHEDULER_FREQUENCY
    )
    expect_job_args_to_equal(
      hash[:args], [{ last_run_time: run_time.iso8601, job_dictionary: full_dictionary }]
    )
  end

  def expect_job_args_to_equal(args, to_equal)
    args_sym = JSON.parse(args.to_json, symbolize_names: true)
    expect(args_sym).to eq(to_equal)
  end
end
