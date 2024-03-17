require_relative "audit"
require_relative "db"
require_relative "migrations"

module Que
  module Scheduler
    module StateChecks
      class << self
        def check
          assert_db_migrated
        end

        # rubocop:disable Metrics/MethodLength
        private def assert_db_migrated
          db_version = Que::Scheduler::Migrations.db_version
          return if db_version == Que::Scheduler::Migrations::MAX_VERSION

          sync_err =
            if Que::Scheduler::VersionSupport.running_synchronously? && db_version.zero?
              code = Que::Scheduler::VersionSupport.running_synchronously_code?
              <<~ERR_SYNC
                You currently have Que to run in synchronous mode using
                #{code}, so it is most likely this error
                has happened during an initial migration. You should disable synchronous mode and
                try again. Note, que-scheduler uses "forward time" scheduled jobs, so will not work
                in synchronous mode.

              ERR_SYNC
            end

          raise(<<-ERR)
            The que-scheduler db migration state was found to be #{db_version}. It should be #{Que::Scheduler::Migrations::MAX_VERSION}.
            #{sync_err}
            que-scheduler adds some tables to the DB to provide an audit history of what was
            enqueued when, and with what options and arguments. The structure of these tables is
            versioned, and should match that version required by the gem.

            The currently migrated version of the audit tables is held in a table COMMENT (much like
            how que keeps track of its DB versions). You can check the current DB version by
            querying the COMMENT on the #{Que::Scheduler::Audit::TABLE_NAME} table like this:

            #{Que::Scheduler::Migrations::TABLE_COMMENT}

            Or you can use ruby:

              Que::Scheduler::Migrations.db_version

            To bring the db version up to the current one required, add a migration like this. It
            is cumulative, so one line is sufficient to perform all necessary steps.

            class UpdateQueSchedulerSchema < ActiveRecord::Migration[6.0]
              def change
                Que::Scheduler::Migrations.migrate!(version: #{Que::Scheduler::Migrations::MAX_VERSION})
              end
            end

            It is also possible that you are running a migration with Que set up to execute jobs
            synchronously. This will fail as que-scheduler needs the above tables to work.
          ERR
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
