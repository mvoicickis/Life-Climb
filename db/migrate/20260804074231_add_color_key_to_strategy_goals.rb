# frozen_string_literal: true

class AddColorKeyToStrategyGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :strategy_goals, :color_key, :string
  end
end
