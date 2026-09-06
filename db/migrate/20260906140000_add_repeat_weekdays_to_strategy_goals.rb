# frozen_string_literal: true

class AddRepeatWeekdaysToStrategyGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :strategy_goals, :repeat_weekdays, :json
  end
end
