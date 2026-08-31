# frozen_string_literal: true

class CreateUserEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :user_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.json :properties, null: false, default: {}

      t.timestamps
    end

    add_index :user_events, [ :user_id, :name, :created_at ]
    add_index :user_events, [ :name, :created_at ]
  end
end
