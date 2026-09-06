# frozen_string_literal: true

module Today
  # Open Mountain battles with no incomplete DailyTodo for the given day (cap overflow).
  class BattlesWaiting
    def self.count(user:, life_area:, on: Date.current)
      new(user:, life_area:, on:).count
    end

    def initialize(user:, life_area:, on:)
      @user = user
      @life_area = life_area
      @on = on
    end

    def count
      eligible_ids = eligible_battle_ids
      return 0 if eligible_ids.empty?

      surfaced_ids = @user.daily_todos.for_day(@on).incomplete
        .where(strategy_goal_id: eligible_ids)
        .distinct
        .pluck(:strategy_goal_id)

      eligible_ids.size - surfaced_ids.size
    end

    private

    def eligible_battle_ids
      one_shots = @user.strategy_goals
        .where(life_area_id: @life_area.id, horizon: "day", repeat: "none")
        .incomplete
        .not_holding
        .where("scheduled_on IS NULL OR scheduled_on <= ?", @on)
        .pluck(:id)

      dailies = @user.strategy_goals
        .where(life_area_id: @life_area.id, horizon: "day", repeat: "daily")
        .incomplete
        .not_holding
        .where("scheduled_on IS NULL OR scheduled_on <= ?", @on)
        .pluck(:id)

      weeklies = @user.strategy_goals
        .where(life_area_id: @life_area.id, horizon: "day", repeat: "weekly")
        .incomplete
        .not_holding
        .where("scheduled_on IS NULL OR scheduled_on <= ?", @on)
        .select { |goal| goal.repeats_on?(@on) }
        .map(&:id)

      one_shots + dailies + weeklies
    end
  end
end
