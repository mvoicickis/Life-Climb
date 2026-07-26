# frozen_string_literal: true

class CreateJourneyTargets < ActiveRecord::Migration[8.1]
  def change
    create_table :journey_targets do |t|
      t.references :life_journey, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :kind, null: false, default: "oneshot"
      t.decimal :target_value, precision: 12, scale: 2, null: false, default: "1.0"
      t.decimal :current_value, precision: 12, scale: 2, null: false, default: "0.0"
      t.string :unit
      t.json :tags, null: false, default: []
      t.string :status, null: false, default: "active"
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :journey_targets, [ :life_journey_id, :status ]
    add_column :daily_todos, :tag, :string
  end
end
