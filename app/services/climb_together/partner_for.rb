# frozen_string_literal: true

module ClimbTogether
  # The other User in an active partnership, or nil.
  class PartnerFor
    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      partnership = ClimbPartnership.active_for(@user).order(:id).first
      return nil unless partnership

      partnership.partner_of(@user)
    end
  end
end
