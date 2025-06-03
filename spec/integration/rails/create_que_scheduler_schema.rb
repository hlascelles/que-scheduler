class CreateQueSchedulerSchema < ActiveRecord::Migration[6.0]
  # :reek:UtilityFunction - A migration.
  def change
    Que.migrate!(version: ::Que::Migrations::CURRENT_VERSION)
    Que::Scheduler::Migrations.migrate!(version: ::Que::Scheduler::Migrations::MAX_VERSION)
    Que::Scheduler::Migrations.reenqueue_scheduler_if_missing
  end
end
