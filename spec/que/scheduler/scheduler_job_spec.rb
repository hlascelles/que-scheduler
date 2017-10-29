require 'spec_helper'
require 'que/testing'
require 'timecop'
require 'yaml'
require 'active_record'
require 'active_support/core_ext/numeric/time'

RSpec.describe Que::Scheduler::SchedulerJob do
  QSSJ = described_class
  PARSER = Que::Scheduler::ScheduleParser
  RESULT = Que::Scheduler::ScheduleParserResult

  context 'scheduling' do
    before(:each) do
      expect(::ActiveRecord::Base).to receive(:transaction) do |_, &block|
        block.call
      end
      Que.adapter.jobs.clear
    end

    let(:run_time) { Time.parse('2017-11-08T13:50:32') }

    around(:each) do |example|
      Timecop.freeze(run_time) do
        example.run
      end
    end

    it 'enqueues nothing having loaded the dictionary on the first run' do
      run_test(nil, [], {}, [])
      expect_scheduled([], [])
    end

    it 'enqueues nothing if it knows about a job, but it is not overdue' do
      run_test(
        run_time - 15.minutes,
        %w[HalfHourlyTestJob],
        {},
        %w[HalfHourlyTestJob]
      )
    end

    it 'enqueues nothing if it knows about one job, and a deploy has added a new one' do
      run_test(
        run_time - 15.minutes,
        %w[HalfHourlyTestJob],
        {},
        %w[HalfHourlyTestJob SomeNewJob]
      )
    end

    it 'enqueues known jobs that are overdue' do
      run_test(
        run_time - 45.minutes,
        %w[HalfHourlyTestJob],
        { HalfHourlyTestJob => [[]] },
        %w[HalfHourlyTestJob]
      )
    end

    it 'can enqueue the same job multiple times with different args' do
      run_test(
        run_time - 45.minutes,
        %w[HalfHourlyTestJob],
        { HalfHourlyTestJob => [['foo'], ['bar']] },
        %w[HalfHourlyTestJob]
      )
    end

    it 'should remove jobs from the dictionary that are no longer in the schedule' do
      run_test(
        run_time - 45.minutes,
        %w[HalfHourlyTestJob OldRemovedJob],
        { HalfHourlyTestJob => [[]] },
        %w[HalfHourlyTestJob]
      )
    end

    def run_test(last_time, known_jobs, to_schedule, new_dictionary)
      parser_args = [QSSJ.scheduler_config, run_time, last_time || run_time, known_jobs]
      expect(PARSER).to receive(:parse).with(*parser_args).and_return(
        RESULT.new(to_schedule, new_dictionary, 60)
      )
      if last_time
        QSSJ.run(last_time.to_s, known_jobs)
      else
        QSSJ.run
      end
      expect_scheduled(to_schedule, new_dictionary)
    end

    # This method checks what jobs have been enqueued against a provided list. In addition, the
    # main scheduler job should have enqueued itself.
    def expect_scheduled(list, new_dictionary)
      out = Que.adapter.jobs.values.flatten.map { |v| { Object.const_get(v.job_class) => v.args } }
      itself = job_class_and_args_array_to_jobs(
        QSSJ => [[Time.current + PARSER::SCHEDULER_FREQUENCY, new_dictionary]]
      )
      list_as_scheduled_jobs = job_class_and_args_array_to_jobs(list)
      (list_as_scheduled_jobs + itself).each do |job|
        expect(out).to include(job)
        out -= [job]
      end
    end

    # The parser returns a hash of what needs to be scheduled, keyed on job class, with the value
    # being an array of the sets of args to enqueue. Convert that format here to the verbose
    # expanded format for Que testing.
    def job_class_and_args_array_to_jobs(list)
      list.map do |clazz, sets_of_args|
        sets_of_args.map do |args|
          [clazz, args]
        end.to_h
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
