# frozen_string_literal: true

class CreateStrategyQuantityLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :strategy_quantity_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :strategy_goal, null: false, foreign_key: true
      t.references :source_day, foreign_key: { to_table: :strategy_goals }
      t.references :daily_todo, foreign_key: true
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :unit, null: false
      t.date :logged_on, null: false
      t.timestamps
    end

    add_index :strategy_quantity_logs, [ :strategy_goal_id, :logged_on ]
    add_index :strategy_quantity_logs, [ :user_id, :logged_on ]
  end
end
