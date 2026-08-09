# frozen_string_literal: true

class AddTimelineFieldsToDailyTodosAndUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :daily_todos, bulk: true do |t|
      t.time :start_time
      t.time :end_time
      t.datetime :miss_settled_at
    end

    change_table :users, bulk: true do |t|
      t.integer :day_shields_available, null: false, default: 1
      t.date :day_shield_on
    end
  end
end
