# frozen_string_literal: true

module Missions
  # Ensures today's missions for focused journeys. Never call from GET.
  class EnsureDaily
    DEFAULT_LP = 50
    DEFAULT_GAP_BP = 80

    def self.call(user:, date: Date.current)
      new(user:, date:).call
    end

    def initialize(user:, date:)
      @user = user
      @date = date
    end

    def call
      return [] unless @user.planning_v2?

      focused = @user.life_journeys.focused.to_a
      return [] if focused.empty?

      ActiveRecord::Base.transaction do
        focused.filter_map do |journey|
          ensure_for_journey(journey)
        end
      end
    end

    private

    def ensure_for_journey(journey)
      # Only the primary focus journey gets an auto mission — keeps Home calm.
      return nil unless journey.focus_position == 1

      existing = journey.missions.for_day(@date).incomplete.primary.first
      return existing if existing

      completed_primary = journey.missions.for_day(@date).primary.complete.first
      return completed_primary if completed_primary

      journey.missions.create!(
        user: @user,
        title: mission_title(journey),
        scheduled_on: @date,
        lp_reward: DEFAULT_LP,
        gap_delta_basis_points: DEFAULT_GAP_BP,
        status: "pending",
        source: "system",
        is_primary: true,
        position: 0
      )
    end

    def mission_title(journey)
      I18n.t(
        "missions.generated_title",
        journey: journey.title,
        ideal: journey.ideal_scene.to_s.truncate(60)
      )
    end
  end
end
