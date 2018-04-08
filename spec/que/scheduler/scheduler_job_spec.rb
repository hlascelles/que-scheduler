require 'spec_helper'
require 'que/testing'
require 'timecop'
require 'yaml'
require 'active_support/core_ext/numeric/time'

RSpec.describe Que::Scheduler::SchedulerJob do
  QSSJ = described_class
  QS = Que::Scheduler
  PARSER = QS::EnqueueingCalculator
  RESULT = QS::EnqueueingCalculator::Result

  context 'scheduling' do
    before(:each) do
      allow(QS::Adapters::Orm.instance).to receive(:count_schedulers).and_return(scheduler_jobs)
      allow(QS::Adapters::Orm.instance).to receive(:transaction) do |_, &block|
        block.call
      end
    end

    let(:job) { QSSJ.new({}) }
    let(:scheduler_jobs) { 1 }
    let(:run_time) { Time.zone.parse('2017-11-08T13:50:32') }

    around(:each) do |example|
      Timecop.freeze(run_time) do
        example.run
      end
    end

    before(:each) do
      apply_db_time_now
    end

    it 'enqueues nothing having loaded the dictionary on the first run' do
      run_test(nil, {}, [])
    end

    it 'enqueues nothing if it knows about a job, but it is not overdue' do
      run_test(
        {
          last_run_time: (run_time - 15.minutes).iso8601,
          job_dictionary: %w[HalfHourlyTestJob],
        },
        {},
        %w[HalfHourlyTestJob]
      )
    end

    it 'enqueues nothing if it knows about one job, and a deploy has added a new one' do
      run_test(
        {
          last_run_time: (run_time - 15.minutes).iso8601,
          job_dictionary: %w[HalfHourlyTestJob],
        },
        {},
        %w[HalfHourlyTestJob SomeNewJob]
      )
    end

    it 'enqueues known jobs that are overdue' do
      run_test(
        {
          last_run_time: (run_time - 45.minutes).iso8601,
          job_dictionary: %w[HalfHourlyTestJob],
        },
        { HalfHourlyTestJob => [{}] },
        %w[HalfHourlyTestJob]
      )
    end

    it 'should remove jobs from the dictionary that are no longer in the schedule' do
      run_test(
        {
          last_run_time: (run_time - 45.minutes).iso8601,
          job_dictionary: %w[HalfHourlyTestJob OldRemovedJob],
        },
        { HalfHourlyTestJob => [{}] },
        %w[HalfHourlyTestJob]
      )
    end

    def expect_parse(scheduler_job_args, new_dictionary, to_schedule)
      expect(PARSER).to receive(:parse).with(
        ::Que::Scheduler::DefinedJob.defined_jobs, scheduler_job_args
      ).and_return(
        RESULT.new(missed_jobs: to_schedule, schedule_dictionary: new_dictionary)
      )
    end

    def run_test(initial_job_args, to_schedule, new_dictionary)
      scheduler_job_args = QS::SchedulerJobArgs.build(initial_job_args)
      expect_parse(scheduler_job_args, new_dictionary, to_schedule)
      if initial_job_args
        job.run(initial_job_args)
      else
        job.run
      end
      expect_scheduled(to_schedule, new_dictionary)
    end

    def expect_itself_enqueued(last_run_time, as_time, new_dictionary)
      itself_jobs = Que.adapter.jobs.delete(QS::SchedulerJob)
      expect(itself_jobs.count).to eq(1)
      expect(itself_jobs.first.to_h).to eq(
        queue: nil,
        priority: 0,
        run_at: as_time.beginning_of_minute + QSSJ::SCHEDULER_FREQUENCY,
        job_class: 'Que::Scheduler::SchedulerJob',
        args: [{ last_run_time: last_run_time.iso8601, job_dictionary: new_dictionary }]
      )
    end

    # This method checks what jobs have been enqueued against a provided list. In addition, the
    # main scheduler job should have enqueued itself.
    def expect_scheduled(list, new_dictionary)
      expect_itself_enqueued(run_time, run_time, new_dictionary)

      all_enqueued = Que.adapter.jobs.each_key.map do |job_class|
        job_class_items = Que.adapter.jobs.delete(job_class)
        args = job_class_items.map do |job_class_item|
          expect(job_class_item.to_h[:queue]).to eq(nil)
          expect(job_class_item.to_h[:priority]).to eq(nil)
          expect(job_class_item.to_h[:run_at]).to eq(nil)
          expect(job_class_item.to_h[:job_class]).to eq(job_class.to_s)
          {}
        end
        [job_class, args]
      end.to_h
      expect(all_enqueued).to eq(list)
    end

    describe '#handle_db_clock_change_backwards' do
      # The scheduler job must notice when the db is reporting a time further back
      # than the last time it ran. The job should do nothing except reschedule itself.
      it 'handled by rescheduling self' do
        last_run = Time.zone.parse('2017-11-08T13:50:32')

        Timecop.freeze(last_run - 1.hour) do
          apply_db_time_now
          expect(job).to receive(:handle_db_clock_change_backwards).and_call_original
          job.run(last_run_time: last_run.iso8601, job_dictionary: %w[SomeJob])
          expect_itself_enqueued(last_run, Time.zone.now, %w[SomeJob])
        end
      end
    end

    describe '#assert_one_scheduler_job' do
      let(:scheduler_jobs) { 2 }

      it 'detects if there is more than one SchedulerJob' do
        expect do
          QSSJ.run
        end.to raise_error(
          'Only one Que::Scheduler::SchedulerJob should be enqueued. 2 were found.'
        )
      end
    end

    describe '#enqueue_required_jobs' do
      def test_enqueue_required_jobs(overdue_dictionary)
        result = RESULT.new(missed_jobs: overdue_dictionary, schedule_dictionary: [])
        job.enqueue_required_jobs(result, [])
      end

      def expect_one_result(args, queue, priority)
        expect(HalfHourlyTestJob.jobs.count).to eq(1)
        one_result = HalfHourlyTestJob.jobs.first
        expect(one_result.args).to eq(args)
        expect(one_result.queue).to eq(queue)
        expect(one_result.priority).to eq(priority)
        expect(one_result.run_at).to be nil
        expect(one_result.job_class).to eq('HalfHourlyTestJob')
      end

      it 'schedules nothing if nothing in the result' do
        test_enqueue_required_jobs({})
        expect(Que.adapter.jobs.map(&:args)).to eq([])
      end

      it 'schedules nothing if a job is known but is not overdue' do
        test_enqueue_required_jobs(HalfHourlyTestJob => [])
        expect(HalfHourlyTestJob.jobs.map(&:args)).to eq([])
      end

      it 'schedules one job with no args' do
        test_enqueue_required_jobs(HalfHourlyTestJob => [{}])
        expect_one_result([], nil, nil)
      end

      it 'schedules one job with one String arg' do
        test_enqueue_required_jobs(HalfHourlyTestJob => [{ args: 'foo' }])
        expect_one_result(['foo'], nil, nil)
      end

      it 'schedules one job with one Hash arg' do
        test_enqueue_required_jobs(HalfHourlyTestJob => [{ args: { bar: 'foo' } }])
        expect_one_result([{ bar: 'foo' }], nil, nil)
      end

      it 'schedules one job with one Array arg' do
        test_enqueue_required_jobs(HalfHourlyTestJob => [{ args: %w[foo bar] }])
        expect_one_result(%w[foo bar], nil, nil)
      end

      it 'schedules one job with one String arg and a queue' do
        test_enqueue_required_jobs(HalfHourlyTestJob => [{ args: 'foo', queue: 'baz' }])
        expect_one_result(['foo'], 'baz', nil)
      end

      it 'schedules one job with one String arg and a priority' do
        test_enqueue_required_jobs(HalfHourlyTestJob => [{ args: 'foo', priority: 10 }])
        expect_one_result(['foo'], nil, 10)
      end

      it 'schedules one job with one Hash arg and a queue' do
        test_enqueue_required_jobs(HalfHourlyTestJob => [{ args: { bar: 'foo' }, queue: 'baz' }])
        expect_one_result([{ bar: 'foo' }], 'baz', nil)
      end

      it 'schedules one job with one Hash arg and a priority' do
        test_enqueue_required_jobs(HalfHourlyTestJob => [{ args: { bar: 'foo' }, priority: 10 }])
        expect_one_result([{ bar: 'foo' }], nil, 10)
      end

      it 'schedules one job with one Array arg and a queue' do
        test_enqueue_required_jobs(HalfHourlyTestJob => [{ args: %w[foo bar], queue: 'baz' }])
        expect_one_result(%w[foo bar], 'baz', nil)
      end

      it 'schedules one job with one Array arg and a priority' do
        test_enqueue_required_jobs(HalfHourlyTestJob => [{ args: %w[foo bar], priority: 10 }])
        expect_one_result(%w[foo bar], nil, 10)
      end

      it 'schedules one job with a mixed arg, and a priority, and a queue' do
        test_enqueue_required_jobs(
          HalfHourlyTestJob => [
            { args: { baz: 10, array_baz: ['foo'] }, queue: 'bar', priority: 10 }
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
      expect(QSSJ.instance_variable_get('@priority')).to eq(0)
    end
  end
end
