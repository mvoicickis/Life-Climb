# frozen_string_literal: true

class AddRepeatToStrategyGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :strategy_goals, :repeat, :string, null: false, default: "none"
    add_index :strategy_goals, [ :user_id, :horizon, :repeat ],
              name: "index_strategy_goals_on_user_horizon_repeat"
  end
end
