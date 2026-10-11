# typed: true

require "sorbet-runtime"
require_relative "job_adapters"
require_relative "types"

module Que
  module Scheduler
    # A job the scheduler has decided to enqueue.
    class ToEnqueue < T::Struct
      extend T::Sig

      const :job_class, Class
      const :args, T::Array[T.anything], default: []
      # nil means use the job class's own queue and priority
      const :queue, T.nilable(String)
      const :priority, T.nilable(Integer)
      const :run_at, Types::TIME

      sig { returns(T.nilable(EnqueuedJob)) }
      def enqueue = JobAdapters.adapter_for(job_class).enqueue(self)
    end

    # A job as it was actually enqueued, read back after the enqueue.
    class EnqueuedJob < T::Struct
      const :job_class, String
      const :args, T::Array[T.anything]
      const :queue, String
      const :priority, Integer
      const :run_at, Types::TIME
      const :job_id, Integer
    end
  end
end
