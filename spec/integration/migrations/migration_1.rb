class Migration1 < ActiveRecord::Migration[6.0]
  # :reek:UtilityFunction - A migration.
  def change
    Que.migrate!(version: 3)
    Que::Scheduler::Migrations.migrate!(version: 6)
  end
end
