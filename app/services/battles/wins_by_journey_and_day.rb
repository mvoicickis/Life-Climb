# frozen_string_literal: true

module Battles
  # Strategy battle wins per journey per local calendar day — same eligibility as
  # WinsOnLocalDate. Batched: two queries over a short window (default 7 days).
  class WinsByJourneyAndDay
    def self.call(user:, days: 7)
      new(user:, days:).call
    end

    def initialize(user:, days: 7)
      @user = user
      @days = [ days.to_i, 1 ].max
    end

    # { journey_id => { Date => Integer } }
    def call
      zone_name = WinsOnLocalDate.time_zone_for(@user)
      zone = Time.find_zone!(zone_name)
      to = WinsOnLocalDate.local_today_for(@user)
      from = to - (@days - 1)

      range_start = zone.local(from.year, from.month, from.day).beginning_of_day
      range_end = zone.local(to.year, to.month, to.day).end_of_day

      counts = Hash.new { |hash, journey_id| hash[journey_id] = Hash.new(0) }

      WinsOnLocalDate.one_shot_battles_completed_in_range(
        user: @user,
        range_start: range_start,
        range_end: range_end
      ).where.not(life_journey_id: nil)
        .pluck(:life_journey_id, :completed_at)
        .each do |journey_id, completed_at|
          local_day = completed_at.in_time_zone(zone).to_date
          counts[journey_id][local_day] += 1
        end

      WinsOnLocalDate.recurring_strategy_todos_in_date_range(
        user: @user,
        from: from,
        to: to
      ).where.not(strategy_goals: { life_journey_id: nil })
        .pluck("strategy_goals.life_journey_id", :scheduled_on)
        .each do |journey_id, scheduled_on|
          counts[journey_id][scheduled_on] += 1
        end

      counts
    end
  end
end
