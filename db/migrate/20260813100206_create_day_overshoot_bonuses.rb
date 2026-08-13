# frozen_string_literal: true

class CreateDayOvershootBonuses < ActiveRecord::Migration[8.1]
  def change
    create_table :day_overshoot_bonuses do |t|
      t.references :user, null: false, foreign_key: true
      t.date :on_date, null: false
      t.integer :peak_percent, null: false, default: 0
      t.integer :awarded_ap, null: false, default: 0

      t.timestamps
    end

    add_index :day_overshoot_bonuses, [ :user_id, :on_date ], unique: true
  end
end
