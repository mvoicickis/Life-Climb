# frozen_string_literal: true

module Battles
  # Calendar-day battle wins in the user's time zone — shared by notifications and Stats.
  class WinsOnLocalDate
    RECURRING_REPEATS = %w[daily weekly].freeze

    def self.count_for_date(user:, date:, time_zone:)
      counts_by_date(user: user, from: date, to: date, time_zone: time_zone)[date].to_i
    end

    def self.counts_by_date(user:, from:, to:, time_zone:)
      zone = Time.find_zone!(time_zone)
      counts = Hash.new(0)

      range_start = zone.local(from.year, from.month, from.day).beginning_of_day
      range_end = zone.local(to.year, to.month, to.day).end_of_day

      one_shot_battles_completed_in_range(user: user, range_start: range_start, range_end: range_end)
        .pluck(:completed_at)
        .each do |completed_at|
          counts[completed_at.in_time_zone(zone).to_date] += 1
        end

      recurring_strategy_todos_in_date_range(user: user, from: from, to: to)
        .pluck(:scheduled_on)
        .each do |scheduled_on|
          counts[scheduled_on] += 1
        end

      counts
    end

    def self.ever?(user:)
      zone_name = time_zone_for(user)
      zone = Time.find_zone!(zone_name)
      to = local_today_for(user)
      from = user.created_at.in_time_zone(zone).to_date
      from = to if from > to

      range_start = zone.local(from.year, from.month, from.day).beginning_of_day
      range_end = zone.local(to.year, to.month, to.day).end_of_day

      one_shot_battles_completed_in_range(user: user, range_start: range_start, range_end: range_end).exists? ||
        recurring_strategy_todos_in_date_range(user: user, from: from, to: to).exists?
    end

    def self.time_zone_for(user)
      user.notification_preference&.time_zone.presence || "UTC"
    end

    def self.local_today_for(user)
      zone_name = time_zone_for(user)
      zone = Time.find_zone(zone_name)
      return Date.current unless zone

      Time.current.in_time_zone(zone).to_date
    rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier
      Date.current
    end

    # Shared "won" relations — one-shot battles and recurring strategy todos.
    # Stats, streaks, and My world all use these; do not copy the conditions.
    def self.one_shot_battles_won(user:)
      user.strategy_goals.battles
        .where.not(repeat: RECURRING_REPEATS)
        .where.not(completed_at: nil)
    end

    def self.one_shot_battles_completed_in_range(user:, range_start:, range_end:)
      one_shot_battles_won(user: user).where(completed_at: range_start..range_end)
    end

    def self.recurring_strategy_todos_won(user:)
      base = user.daily_todos.where.not(completed_at: nil)
      strategy_rows = base.where.not(strategy_goal_id: nil).or(base.where(tag: "strategy"))
      strategy_rows
        .joins(:strategy_goal)
        .where(strategy_goals: { repeat: RECURRING_REPEATS })
    end

    def self.recurring_strategy_todos_in_date_range(user:, from:, to:)
      recurring_strategy_todos_won(user: user).where(scheduled_on: from..to)
    end
  end
end
