# frozen_string_literal: true

class AddPlayAppSeenAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :play_app_seen_at, :datetime
  end
end
