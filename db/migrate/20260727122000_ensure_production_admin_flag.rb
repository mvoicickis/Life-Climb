# frozen_string_literal: true

class EnsureProductionAdminFlag < ActiveRecord::Migration[8.0]
  # Render free has no shell — promote the configured admin email on deploy.
  def up
    email = ENV["ADMIN_EMAIL"].presence || "mvoicickis@gmail.com"
    user = User.find_by(email_address: email.to_s.strip.downcase)
    return unless user

    user.update_columns(admin: true)
  end

  def down
    # no-op — do not strip admin on rollback
  end
end
