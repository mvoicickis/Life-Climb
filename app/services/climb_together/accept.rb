# frozen_string_literal: true

module ClimbTogether
  # Accept a pending invite by token. Sets invitee, active, accepted_at.
  class Accept
    def self.call(user:, token:)
      new(user: user, token: token).call
    end

    def initialize(user:, token:)
      @user = user
      @token = token.to_s
    end

    def call
      raise Error, "Invite not found" if @token.blank?

      partnership = ClimbPartnership.find_by(token: @token)
      raise Error, "Invite not found" unless partnership
      raise Error, "Invite is not pending" unless partnership.pending?
      raise Error, "Can't accept your own invite" if partnership.inviter_id == @user.id
      raise Error, "Already have an active partner" if ClimbPartnership.active_for(@user).exists?
      raise Error, "Inviter already has an active partner" if ClimbPartnership.active_for(partnership.inviter).exists?

      partnership.update!(
        invitee: @user,
        status: "active",
        accepted_at: Time.current
      )
      partnership
    end
  end
end
