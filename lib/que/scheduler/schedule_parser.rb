require 'fugit'

module Que
  module Scheduler
    ScheduleParserResult = Struct.new(:missed_jobs, :schedule_dictionary, :seconds_until_next_job)

    class ScheduleParser
      SCHEDULER_FREQUENCY = 60

      class << self
        def parse(jobs_list, as_time, last_time, known_jobs)
          missed_jobs = {}
          schedule_dictionary = []

          # For each scheduled item, we need not schedule a job it if it has no history, as it is
          # new. Otherwise, check how many times we have missed the job since the last run time.
          # If it is "unmissable" then we schedule all of them, with the missed time as an arg,
          # otherwise just schedule it once.
          jobs_list.each do |desc|
            schedule_dictionary << desc[:name]

            next unless known_jobs.include?(desc[:name])
            # This has been seen before. We should check if we have missed any executions.
            missed = calculate_missed_runs(desc, last_time, as_time)
            missed_jobs[desc[:clazz]] = missed unless missed.empty?
          end

          seconds_until_next_job = SCHEDULER_FREQUENCY # TODO: make it 1 sec after next known run
          ScheduleParserResult.new(missed_jobs, schedule_dictionary, seconds_until_next_job)
        end

        private

        def calculate_missed_runs(desc, last_scheduler_run_time, as_time)
          jobs_for_class = []
          missed_times = []
          last_time = last_scheduler_run_time
          while (next_run = next_run_time(desc[:cron], last_time, as_time))
            missed_times << next_run
            last_time = next_run
          end

          unless missed_times.empty?
            if desc[:unmissable]
              missed_times.each do |time_missed|
                jobs_for_class << [time_missed] + desc[:args]
              end
            else
              jobs_for_class << desc[:args]
            end
          end
          jobs_for_class
        end

        def next_run_time(cron, from, to)
          fugit_cron = Fugit::Cron.parse(cron)
          next_time = fugit_cron.next_time(from)
          next_run = next_time.to_local_time.in_time_zone(next_time.zone)
          next_run <= to ? next_run : nil
        end
      end
    end
  end
end
