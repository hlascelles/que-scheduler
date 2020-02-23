MIGRATION_CONSTANT =
  if ENV.fetch('RAILS_VERSION').split('.').first.to_i > 4
    ActiveRecord::Migration[5.2]
  else
    ActiveRecord::Migration
  end

class CreateQueSchedulerSchema < MIGRATION_CONSTANT
  # :reek:UtilityFunction - A migration.
  def change
    Que.migrate!(version: ::Que::Migrations::CURRENT_VERSION)
    Que::Scheduler::Migrations.migrate!(version: ::Que::Scheduler::Migrations::MAX_VERSION)
  end
end
