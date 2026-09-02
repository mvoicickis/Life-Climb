# frozen_string_literal: true

module Admin
  # Ensures a production admin can sign in without Render Shell.
  #
  # Env (set in Render dashboard):
  #   ADMIN_EMAIL=you@example.com
  #   ADMIN_PASSWORD=at-least-8-chars
  #
  # Creates the user if missing, sets admin=true, and (when password present)
  # resets the password so you can log in.
  class Bootstrap
    def self.ensure!
      new.ensure!
    end

    def ensure!
      email = ENV["ADMIN_EMAIL"].to_s.strip.downcase.presence
      password = ENV["ADMIN_PASSWORD"].presence || ENV["ADMIN_BOOTSTRAP_PASSWORD"].presence
      return { ok: false, reason: "ADMIN_EMAIL missing" } if email.blank?

      user = User.find_or_initialize_by(email_address: email)
      user.name = user.name.presence || "Admin"
      user.home_stat_count = user.home_stat_count.presence || 6
      user.admin = true
      user.onboarding_completed_at ||= Time.current
      user.planning_version = 2 if user.planning_version.blank?

      creating = user.new_record?

      if password.present?
        if password.length < TextLimits::PASSWORD_MIN
          return { ok: false, reason: "ADMIN_PASSWORD must be at least #{TextLimits::PASSWORD_MIN} characters" }
        end
        user.password = password
        user.password_confirmation = password
      elsif creating
        return { ok: false, reason: "ADMIN_PASSWORD required to create admin user" }
      end

      user.save!
      { ok: true, email: user.email_address, created: creating }
    rescue StandardError => e
      { ok: false, reason: e.message }
    end
  end
end
