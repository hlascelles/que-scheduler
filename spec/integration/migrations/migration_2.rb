class Migration2 < ActiveRecord::Migration[6.0]
  # :reek:UtilityFunction - A migration.
  def change
    Que.migrate!(version: 7)
    Que::Scheduler::Migrations.reenqueue_scheduler_if_missing
  end
end
