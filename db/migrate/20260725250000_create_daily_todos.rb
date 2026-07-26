# frozen_string_literal: true

class CreateDailyTodos < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_todos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :aspect_key, null: false
      t.date :scheduled_on, null: false
      t.datetime :completed_at
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :daily_todos, [ :user_id, :scheduled_on, :aspect_key ]
  end
end
