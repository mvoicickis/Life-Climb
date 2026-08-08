# frozen_string_literal: true

class AddManuallyCompletedAtToStrategyGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :strategy_goals, :manually_completed_at, :datetime
  end
end
