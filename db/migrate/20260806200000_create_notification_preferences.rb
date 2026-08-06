# frozen_string_literal: true

class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :frequency, null: false, default: "sometimes"
      t.string :intensity, null: false, default: "normal"
      t.integer :quiet_hours_start
      t.integer :quiet_hours_end
      t.string :time_zone
      t.date :vacation_until
      t.boolean :vacation_paused, null: false, default: false
      t.boolean :win_notifications_enabled, null: false, default: true
      t.boolean :stuck_notifications_enabled, null: false, default: true

      t.timestamps
    end
  end
end
