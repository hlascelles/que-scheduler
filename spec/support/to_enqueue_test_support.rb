shared_context "when job testing" do
  if Que::Scheduler::ToEnqueue.active_job_loaded?
    let(:handles_queue_name) {
      Que::Scheduler::ToEnqueue.active_job_version_supports_queues?
    }

    def expected_class_in_db(_enqueued_class)
      ActiveJob::QueueAdapters::QueAdapter::JobWrapper
    end

    def job_args_from_db_row(job_row)
      # ActiveJob args are held in a wrapper which we must mine down to.
      first_args = job_row[:args].first
      # Depending on Que version it may be by symbol or string.
      first_arguments = (first_args["arguments"] || first_args[:arguments])
      first_arguments.each do |arg|
        if arg.is_a?(Hash)
          arg.delete("_aj_symbol_keys")
          arg.delete(:_aj_symbol_keys)
        end
      end
    end

    def null_enqueue_call(_job_class)
      expect_any_instance_of(ActiveJob::ConfiguredJob)
        .to receive(:perform_later).and_return(false)
    end
  else
    let(:handles_queue_name) { true }

    def expected_class_in_db(enqueued_class)
      enqueued_class
    end

    def job_args_from_db_row(job_row)
      job_row[:args]
    end

    def null_enqueue_call(job_class)
      expect(job_class).to receive(:enqueue).and_return(false)
    end
  end
end
