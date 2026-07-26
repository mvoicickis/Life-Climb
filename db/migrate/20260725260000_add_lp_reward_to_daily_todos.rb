# frozen_string_literal: true

class AddLpRewardToDailyTodos < ActiveRecord::Migration[8.1]
  def change
    add_column :daily_todos, :lp_reward, :integer, null: false, default: 30
  end
end
