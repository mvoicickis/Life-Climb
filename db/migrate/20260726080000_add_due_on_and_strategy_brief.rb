# frozen_string_literal: true

class AddDueOnAndStrategyBrief < ActiveRecord::Migration[8.0]
  def change
    add_column :strategy_goals, :due_on, :date
    add_column :life_journeys, :strategy_brief, :json, null: false, default: {}
  end
end
