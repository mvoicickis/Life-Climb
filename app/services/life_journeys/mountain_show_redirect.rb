# frozen_string_literal: true

module LifeJourneys
  # Where to send a user who opened a completed journey Mountain URL (slice 4 may extend).
  class MountainShowRedirect
    def self.path_for(user:, journey:)
      new(user:, journey:).path_for
    end

    def initialize(user:, journey:)
      @user = user
      @journey = journey
    end

    # Returns a path string when the user should leave this journey's Mountain page, else nil.
    def path_for
      return nil unless @journey&.status == "completed"

      current = Goals::Current.journey_for(user: @user)
      return nil if current.blank? || current.id == @journey.id

      Rails.application.routes.url_helpers.life_journey_path(current)
    end
  end
end
