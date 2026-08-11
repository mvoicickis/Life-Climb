# frozen_string_literal: true

class CreatePatternSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :pattern_snapshots do |t|
      t.references :user, null: false, foreign_key: true
      t.date :computed_on, null: false
      t.json :findings, null: false, default: []
      t.timestamps
    end

    add_index :pattern_snapshots, [ :user_id, :computed_on ], unique: true
  end
end
