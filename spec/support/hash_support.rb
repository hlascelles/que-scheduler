def hash_to_enqueues(overdue_dictionary)
  overdue_dictionary.map { |o| Que::Scheduler::DefinedJob::ToEnqueue.new(o) }
end
