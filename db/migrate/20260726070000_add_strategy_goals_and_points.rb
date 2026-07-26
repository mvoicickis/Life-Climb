# frozen_string_literal: true

class AddStrategyGoalsAndPoints < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :strategy_points, :integer, null: false, default: 0

    create_table :strategy_point_ledgers do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount, null: false
      t.string :reason, null: false
      t.string :source_type
      t.integer :source_id
      t.timestamps
    end
    add_index :strategy_point_ledgers, [ :source_type, :source_id ]

    create_table :strategy_goals do |t|
      t.references :user, null: false, foreign_key: true
      t.references :life_area, null: false, foreign_key: true
      t.references :life_journey, foreign_key: true
      t.references :parent, foreign_key: { to_table: :strategy_goals }
      t.string :horizon, null: false
      t.string :title, null: false
      t.date :scheduled_on
      t.integer :position, null: false, default: 0
      t.datetime :completed_at
      t.timestamps
    end

    add_index :strategy_goals, [ :user_id, :life_area_id, :horizon ]
    add_index :strategy_goals, [ :user_id, :scheduled_on ]
    add_index :strategy_goals, [ :parent_id, :position ]

    add_column :daily_todos, :strategy_goal_id, :integer
    add_index :daily_todos, :strategy_goal_id
    add_foreign_key :daily_todos, :strategy_goals, column: :strategy_goal_id
  end
end
