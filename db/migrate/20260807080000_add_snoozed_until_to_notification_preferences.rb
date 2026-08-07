# frozen_string_literal: true

class AddSnoozedUntilToNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :notification_preferences, :snoozed_until, :datetime
  end
end
