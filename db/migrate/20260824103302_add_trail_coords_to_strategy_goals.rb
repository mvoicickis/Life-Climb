# frozen_string_literal: true

class AddTrailCoordsToStrategyGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :strategy_goals, :trail_x, :decimal, precision: 5, scale: 4
    add_column :strategy_goals, :trail_y, :decimal, precision: 5, scale: 4
  end
end
