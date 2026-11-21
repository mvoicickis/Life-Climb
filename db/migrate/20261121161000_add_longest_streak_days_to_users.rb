# frozen_string_literal: true

class AddLongestStreakDaysToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :longest_streak_days, :integer, default: 0, null: false
  end
end
