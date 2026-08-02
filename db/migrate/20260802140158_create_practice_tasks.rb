# frozen_string_literal: true

class CreatePracticeTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :practice_tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :strategy_goal, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :position, null: false, default: 0
      t.datetime :completed_at

      t.timestamps
    end

    add_index :practice_tasks, [ :strategy_goal_id, :position ]
  end
end
