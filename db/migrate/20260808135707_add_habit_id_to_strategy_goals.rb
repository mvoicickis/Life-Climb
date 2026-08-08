# frozen_string_literal: true

class AddHabitIdToStrategyGoals < ActiveRecord::Migration[8.0]
  def change
    add_reference :strategy_goals, :habit, null: true, foreign_key: true
  end
end
