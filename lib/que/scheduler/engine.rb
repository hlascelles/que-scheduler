# frozen_string_literal: true

require 'rails/engine'

module Que
  module Scheduler
    class Engine < ::Rails::Engine
      config.after_initialize do
        # Trigger a load of the schedule to ensure fast fail if it is invalid.
        ::Que::Scheduler::DefinedJob.defined_jobs
      end
    end
  end
end
