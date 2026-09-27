# frozen_string_literal: true

module Notifications
  # Calendar-day battle wins in the user's time zone — not Mountain "done today".
  class BattleWinsOnLocalDate
    RECURRING_REPEATS = %w[daily weekly].freeze

    def self.any?(user:, date:, time_zone:)
      new(user: user, date: date, time_zone: time_zone).any?
    end

    def initialize(user:, date:, time_zone:)
      @user = user
      @date = date
      @time_zone = time_zone
    end

    def any?
      one_shot_won_on_date? || recurring_battle_todo_won?
    end

    private

    def zone
      @zone ||= Time.find_zone!(@time_zone)
    end

    def one_shot_won_on_date?
      day_start = zone.local(@date.year, @date.month, @date.day).beginning_of_day
      day_end = day_start.end_of_day

      @user.strategy_goals.battles
        .where.not(repeat: RECURRING_REPEATS)
        .where(completed_at: day_start..day_end)
        .exists?
    end

    def recurring_battle_todo_won?
      completed_battle_todos
        .joins(:strategy_goal)
        .where(strategy_goals: { repeat: RECURRING_REPEATS })
        .exists?
    end

    def completed_battle_todos
      rows = @user.daily_todos.for_day(@date).where.not(completed_at: nil)
      rows.where.not(strategy_goal_id: nil).or(rows.where(tag: "strategy"))
    end
  end
end
