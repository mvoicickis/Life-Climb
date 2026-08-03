# frozen_string_literal: true

class AddQuantityTrackingToStrategyGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :strategy_goals, :target_amount, :decimal, precision: 12, scale: 2
    add_column :strategy_goals, :unit, :string
    add_column :strategy_goals, :current_amount, :decimal, precision: 12, scale: 2, null: false, default: 0
  end
end
