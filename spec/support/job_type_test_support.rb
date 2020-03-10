shared_context "job testing" do
  if Que::Scheduler::JobTypeSupport::active_job_sufficient_version?
    let(:handles_queue_name) { false }

    def expected_class_in_db(_enqueued_class)
      ActiveJob::QueueAdapters::QueAdapter::JobWrapper
    end

    def job_args(job_row)
      # ActiveJob args are held in a wrapper
      job_row[:args].first['arguments'].each do |arg|
        arg.delete('_aj_symbol_keys') if arg.is_a?(Hash)
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

    def job_args(job_row)
      job_row[:args]
    end

    def null_enqueue_call(job_class)
      expect(job_class).to receive(:enqueue).and_return(false)
    end
  end
end
