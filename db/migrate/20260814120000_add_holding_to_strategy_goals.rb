# frozen_string_literal: true

class AddHoldingToStrategyGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :strategy_goals, :holding, :boolean, null: false, default: false
    add_index :strategy_goals, [ :life_journey_id, :horizon ],
              unique: true,
              where: "holding = TRUE",
              name: "index_strategy_goals_one_holding_per_journey_horizon"
  end
end
