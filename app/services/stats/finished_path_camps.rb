# frozen_string_literal: true

module Stats
  # Finished path-level camps (project under plan) across journeys — matches StrategyGoal#path_level_camp?
  class FinishedPathCamps
    PARENT_JOIN = <<~SQL.squish
      INNER JOIN strategy_goals parents ON parents.id = strategy_goals.parent_id
    SQL

    def self.finished_scope(user:)
      user.strategy_goals
        .where(horizon: "project")
        .not_holding
        .joins(PARENT_JOIN)
        .where(parents: { horizon: "plan" })
        .where.not(completed_at: nil)
    end

    def self.total_count(user:)
      finished_scope(user: user).count
    end

    def self.counts_by_journey(user:, journey_ids:)
      finished_scope(user: user)
        .where(life_journey_id: journey_ids)
        .group(:life_journey_id)
        .count
    end

    def self.completion_dates(user:, time_zone:)
      zone = Time.find_zone!(time_zone)
      finished_scope(user: user)
        .pluck(:completed_at)
        .map { |stamp| stamp.in_time_zone(zone).to_date }
    end
  end
end
