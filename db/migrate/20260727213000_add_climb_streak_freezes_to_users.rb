# frozen_string_literal: true

class AddClimbStreakFreezesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :climb_streak_freezes, :integer, null: false, default: 0
    add_column :users, :climb_streak_frozen_on, :date
    add_column :users, :best_day_ap, :integer, null: false, default: 0
  end
end
