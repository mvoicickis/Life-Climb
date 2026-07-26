# frozen_string_literal: true

class CreateAppSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :app_settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
    end

    add_index :app_settings, :key, unique: true
  end
end
