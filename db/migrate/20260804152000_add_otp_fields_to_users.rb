# frozen_string_literal: true

class AddOtpFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :otp_secret, :text
    add_column :users, :otp_enabled_at, :datetime
    add_column :users, :otp_backup_codes_digest, :json, default: [], null: false
  end
end
