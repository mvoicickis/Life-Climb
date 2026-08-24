# frozen_string_literal: true

class AddTrailCampExtrasToStrategyGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :strategy_goals, :accent_hex, :string
    add_column :strategy_goals, :camp_mode, :string, null: false, default: "battles"
  end
end
