# typed: true

# Accessors that Hashie::Dash `property` defines at runtime. Delete when these become T::Structs.

class Que::Scheduler::DefinedJob
  sig { returns(String) }
  def name; end

  sig { returns(Class) }
  def job_class; end

  sig { returns(Fugit::Cron) }
  def cron; end

  sig { returns(T.nilable(String)) }
  def queue; end

  sig { returns(T.nilable(Integer)) }
  def priority; end

  sig { returns(T::Array[T.anything]) }
  def args_array; end

  sig { returns(Symbol) }
  def schedule_type; end
end

class Que::Scheduler::ToEnqueue
  sig { returns(T.anything) }
  def args; end

  sig { returns(T.nilable(String)) }
  def queue; end

  sig { returns(T.nilable(Integer)) }
  def priority; end

  sig { returns(Que::Scheduler::Types::TIME) }
  def run_at; end

  sig { returns(Class) }
  def job_class; end
end

class Que::Scheduler::EnqueuedJobType
  sig { returns(T::Array[T.anything]) }
  def args; end

  sig { returns(T.nilable(String)) }
  def queue; end

  sig { returns(T.nilable(Integer)) }
  def priority; end

  sig { returns(Que::Scheduler::Types::TIME) }
  def run_at; end

  sig { returns(String) }
  def job_class; end

  sig { returns(Integer) }
  def job_id; end
end

class Que::Scheduler::SchedulerJobArgs
  sig { returns(Que::Scheduler::Types::TIME) }
  def last_run_time; end

  sig { returns(T::Array[String]) }
  def job_dictionary; end

  sig { returns(Que::Scheduler::Types::TIME) }
  def as_time; end
end

class Que::Scheduler::EnqueueingCalculator::Result
  sig { returns(T::Array[Que::Scheduler::ToEnqueue]) }
  def missed_jobs; end

  sig { returns(T::Array[String]) }
  def job_dictionary; end
end
