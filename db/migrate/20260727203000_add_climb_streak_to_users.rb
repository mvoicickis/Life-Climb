# frozen_string_literal: true

class AddClimbStreakToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :climb_streak_days, :integer, null: false, default: 0
    add_column :users, :climb_streak_on, :date
  end
end
