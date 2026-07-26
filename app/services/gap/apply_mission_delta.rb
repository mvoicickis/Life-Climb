# frozen_string_literal: true

module Gap
  class ApplyMissionDelta
    def self.call(journey:, mission:)
      new(journey:, mission:).call
    end

    def initialize(journey:, mission:)
      @journey = journey
      @mission = mission
    end

    def call
      Gap::ApplyProgress.call(
        journey: @journey,
        tier: :mission,
        raw_basis_points: @mission.gap_delta_basis_points
      )
    end
  end
end
