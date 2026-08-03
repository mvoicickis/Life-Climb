# frozen_string_literal: true

class AddObjectiveQuantityTracking < ActiveRecord::Migration[8.1]
  def change
    add_column :practice_tasks, :track_quantity, :boolean, null: false, default: false

    add_reference :strategy_quantity_logs, :practice_task, foreign_key: true, null: true
    add_index :strategy_quantity_logs, :practice_task_id, unique: true,
              where: "practice_task_id IS NOT NULL",
              name: "index_strategy_quantity_logs_on_practice_task_id_unique"
  end
end
