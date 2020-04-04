module HashSupport
  class << self
    def hash_to_enqueues(overdue_dictionary)
      overdue_dictionary.map { |item| Que::Scheduler::ToEnqueue.create(item) }
    end
  end
end
