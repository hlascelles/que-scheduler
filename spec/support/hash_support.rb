module HashSupport
  class << self
    def hash_to_enqueues(overdue_dictionary)
      overdue_dictionary.map { |item| Que::Scheduler::DefinedJob::ToEnqueue.new(item) }
    end
  end
end
