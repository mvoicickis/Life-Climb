# frozen_string_literal: true

class CreateHighFives < ActiveRecord::Migration[8.1]
  def change
    create_table :high_fives do |t|
      t.references :from_user, null: false, foreign_key: { to_table: :users }
      t.references :to_user, null: false, foreign_key: { to_table: :users }
      t.references :strategy_goal, null: false, foreign_key: true
      t.references :daily_todo, null: true, foreign_key: true

      t.timestamps
    end

    add_index :high_fives,
              [ :from_user_id, :strategy_goal_id, :daily_todo_id, :created_at ],
              name: "index_high_fives_on_from_battle_todo_and_created"
  end
end
