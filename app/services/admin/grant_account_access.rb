# frozen_string_literal: true

module Admin
  # One-shot / idempotent privilege grants for specific accounts.
  # Safe to re-run: only flips the requested flags to true; never clears them,
  # and never touches any other user.
  class GrantAccountAccess
    GRANTS = [
      {
        email: "karenchi.s.c@gmail.com",
        admin: true,
        developer: true
      }
    ].freeze

    def self.ensure_all!
      GRANTS.map { |grant| new(**grant).ensure! }
    end

    def initialize(email:, admin: false, developer: false)
      @email = email.to_s.strip.downcase
      @admin = admin
      @developer = developer
    end

    def ensure!
      user = User.find_by(email_address: @email)
      return { ok: false, reason: "user_not_found", email: @email } if user.nil?

      attrs = {}
      attrs[:admin] = true if @admin && !user.admin?
      attrs[:developer] = true if @developer && user.read_attribute(:developer) != true

      if attrs.empty?
        return {
          ok: true,
          email: @email,
          changed: false,
          admin: user.admin?,
          developer: user.read_attribute(:developer) == true
        }
      end

      user.update_columns(attrs)
      user.reload

      {
        ok: true,
        email: @email,
        changed: true,
        admin: user.admin?,
        developer: user.read_attribute(:developer) == true
      }
    end
  end
end
