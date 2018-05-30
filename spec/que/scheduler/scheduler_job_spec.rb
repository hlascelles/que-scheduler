require 'spec_helper'
require 'timecop'
require 'yaml'
require 'active_support/core_ext/numeric/time'

RSpec.describe Que::Scheduler::SchedulerJob do
  QS = Que::Scheduler
  PARSER = QS::EnqueueingCalculator
  RESULT = QS::EnqueueingCalculator::Result
  let(:default_queue) { column_default('que_jobs', 'queue').split(':').first[1..-2] }
  let(:default_priority) { column_default('que_jobs', 'priority').to_i }

  context 'scheduling' do
    include_context('roundtrip tester')

    describe '#assert_one_scheduler_job' do
      it 'detects if there is more than one SchedulerJob' do
        expect do
          described_class.enqueue
          described_class.enqueue
          described_class.run
        end.to raise_error(
          'Only one Que::Scheduler::SchedulerJob should be enqueued. 2 were found.'
        )
      end
    end

    describe '#run' do
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
    end

    describe '#enqueue_required_jobs' do
      def test_enqueued(overdue_dictionary)
        result = RESULT.new(missed_jobs: hash_to_enqueues(overdue_dictionary), job_dictionary: [])
        described_class.new({}).enqueue_required_jobs(result, [])
      end

      def expect_one_result(args, queue, priority)
        jobs = jobs_by_class(HalfHourlyTestJob)
        expect(jobs.count).to eq(1)
        one_result = jobs.first
        expect(one_result['args'] || []).to eq(JSON.parse(args.to_json))
        expect(one_result['queue']).to eq(queue)
        expect(one_result['priority']).to eq(priority)
        expect(one_result['job_class']).to eq('HalfHourlyTestJob')
      end

      it 'schedules nothing if nothing in the result' do
        test_enqueued([])
        expect(Que.job_stats).to eq([])
      end

      it 'schedules one job with no args' do
        test_enqueued([{ job_class: HalfHourlyTestJob }])
        expect_one_result([], default_queue, default_priority)
      end

      it 'schedules one job with one String arg' do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: 'foo' }])
        expect_one_result(['foo'], default_queue, default_priority)
      end

      it 'schedules one job with one Hash arg' do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: { bar: 'foo' } }])
        expect_one_result([{ bar: 'foo' }], default_queue, default_priority)
      end

      it 'schedules one job with one Array arg' do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: %w[foo bar] }])
        expect_one_result(%w[foo bar], default_queue, default_priority)
      end

      it 'schedules one job with one String arg and a queue' do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: 'foo', queue: 'baz' }])
        expect_one_result(['foo'], 'baz', default_priority)
      end

      it 'schedules one job with one String arg and a priority' do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: 'foo', priority: 10 }])
        expect_one_result(['foo'], default_queue, 10)
      end

      it 'schedules one job with one Hash arg and a queue' do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: { bar: 'foo' }, queue: 'baz' }])
        expect_one_result([{ bar: 'foo' }], 'baz', default_priority)
      end

      it 'schedules one job with one Hash arg and a priority' do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: { bar: 'foo' }, priority: 10 }])
        expect_one_result([{ bar: 'foo' }], default_queue, 10)
      end

      it 'schedules one job with one Array arg and a queue' do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: %w[foo bar], queue: 'baz' }])
        expect_one_result(%w[foo bar], 'baz', default_priority)
      end

      it 'schedules one job with one Array arg and a priority' do
        test_enqueued([{ job_class: HalfHourlyTestJob, args: %w[foo bar], priority: 10 }])
        expect_one_result(%w[foo bar], default_queue, 10)
      end

      it 'schedules one job with a mixed arg, and a priority, and a queue' do
        test_enqueued(
          [
            {
              job_class: HalfHourlyTestJob,
              args: { baz: 10, array_baz: ['foo'] },
              queue: 'bar',
              priority: 10,
            }
          ]
        )
        expect_one_result([{ baz: 10, array_baz: ['foo'] }], 'bar', 10)
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
end
