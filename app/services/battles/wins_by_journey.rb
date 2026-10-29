# frozen_string_literal: true

module Battles
  # All-time strategy battle wins per journey — same rules as WinsOnLocalDate /
  # Stats::BattleWins (one-shots + recurring battle todos). Batched: two queries.
  class WinsByJourney
    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      zone_name = WinsOnLocalDate.time_zone_for(@user)
      zone = Time.find_zone!(zone_name)
      to = WinsOnLocalDate.local_today_for(@user)
      from = @user.created_at.in_time_zone(zone).to_date
      from = to if from > to

      range_start = zone.local(from.year, from.month, from.day).beginning_of_day
      range_end = zone.local(to.year, to.month, to.day).end_of_day

      counts = Hash.new(0)

      WinsOnLocalDate.one_shot_battles_completed_in_range(
        user: @user,
        range_start: range_start,
        range_end: range_end
      ).where.not(life_journey_id: nil)
        .group(:life_journey_id)
        .count
        .each { |journey_id, wins| counts[journey_id] += wins }

      WinsOnLocalDate.recurring_strategy_todos_in_date_range(
        user: @user,
        from: from,
        to: to
      ).where.not(strategy_goals: { life_journey_id: nil })
        .group("strategy_goals.life_journey_id")
        .count
        .each { |journey_id, wins| counts[journey_id] += wins }

      counts
    end
  end
end
