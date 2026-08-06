# frozen_string_literal: true

class AddLastMorningNudgeSentOnToNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :notification_preferences, :last_morning_nudge_sent_on, :date
  end
end
