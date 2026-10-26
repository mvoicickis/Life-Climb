# frozen_string_literal: true

class AddStreakCommitmentToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :streak_commitment_target_days, :integer
    add_column :users, :streak_commitment_started_on, :date
    add_column :users, :streak_commit_declines, :integer, null: false, default: 0
  end
end
