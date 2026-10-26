# frozen_string_literal: true

class AddLastStreakMomentOnToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_streak_moment_on, :date
  end
end
