# frozen_string_literal: true

class AddDescriptionToStrategyGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :strategy_goals, :description, :text
  end
end
