# frozen_string_literal: true

module ClimbTogether
  # End the user's active rope-team partnership.
  class End
    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      partnership = ClimbPartnership.active_for(@user).order(:id).first
      raise Error, "No active partner" unless partnership

      partnership.update!(status: "ended", ended_at: Time.current)
      partnership
    end
  end
end
