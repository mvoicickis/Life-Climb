# frozen_string_literal: true

module ClimbTogether
  # Reuse the user's pending invite, or create one. Blocked when already partnered.
  class Invite
    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      raise Error, "Already have an active partner" if ClimbPartnership.active_for(@user).exists?

      existing = ClimbPartnership.pending_invite_by(@user)
      return existing if existing

      ClimbPartnership.create!(inviter: @user, status: "pending")
    end
  end
end
