# frozen_string_literal: true

module Gap
  # Single writer for day-to-day gap progress on the LifePoints alignment stack.
  # Tiers: :todo (small) | :mission (medium). Milestone/journey complete are separate.
  class ApplyProgress
    TIERS = {
      todo: {
        basis_points: GameRules::TODO_GAP_BP,
        abs_cap: GameRules::TODO_ABS_CAP
      },
      mission: {
        basis_points: GameRules::MISSION_DEFAULT_GAP_BP,
        abs_cap: GameRules::MISSION_ABS_CAP
      }
    }.freeze

    def self.call(journey:, tier:, raw_basis_points: nil)
      new(journey: journey, tier: tier, raw_basis_points: raw_basis_points).call
    end

    def initialize(journey:, tier:, raw_basis_points: nil)
      @journey = journey
      @tier = tier.to_sym
      @raw_basis_points = raw_basis_points
    end

    def call
      return nil unless @journey

      config = TIERS.fetch(@tier) { raise ArgumentError, "Unknown progress tier: #{@tier}" }
      basis_points = (@raw_basis_points.presence || config[:basis_points]).to_i
      raw = basis_points / 100.0
      gap = @journey.gap_percent.to_f
      factor = (gap / 100.0).clamp(0.25, 1.0)
      delta = (raw * factor).round(2)
      delta = [ delta, config[:abs_cap] ].min
      delta = 0.0 if delta.negative?
      new_gap = [ gap - delta, 0 ].max.round(2)

      ActiveRecord::Base.transaction do
        @journey.update!(gap_percent: new_gap)
        snapshot = @journey.gap_snapshots.find_or_initialize_by(recorded_on: Date.current)
        snapshot.gap_percent = new_gap
        snapshot.save!
        { gap_percent: new_gap, delta: delta, tier: @tier }
      end
    end
  end
end
