# frozen_string_literal: true

class AddLastEveningNudgeSentOnToNotificationPreferences < ActiveRecord::Migration[8.0]
  def change
    add_column :notification_preferences, :last_evening_nudge_sent_on, :date
  end
end
