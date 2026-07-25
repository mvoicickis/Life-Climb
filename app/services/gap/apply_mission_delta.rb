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
      raw = @mission.gap_delta_basis_points.to_i / 100.0
      # Mild diminishing returns as the gap closes — progress still feels real near the end.
      factor = (@journey.gap_percent.to_f / 100.0).clamp(0.25, 1.0)
      delta = (raw * factor).round(2)
      new_gap = [ @journey.gap_percent.to_f - delta, 0 ].max.round(2)

      ActiveRecord::Base.transaction do
        @journey.update!(gap_percent: new_gap)
        snapshot = @journey.gap_snapshots.find_or_initialize_by(recorded_on: Date.current)
        snapshot.gap_percent = new_gap
        snapshot.save!
        { gap_percent: new_gap, delta: delta }
      end
    end
  end
end
