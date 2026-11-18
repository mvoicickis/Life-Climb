# frozen_string_literal: true

module Admin
  module TestersHelper
    def climbers_month_param(date)
      date.strftime("%Y-%m")
    end

    def climbers_calendar_nav_url(month_date, filter:)
      admin_testers_path(
        filter: filter,
        climbers_month: climbers_month_param(month_date)
      )
    end

    def climbers_calendar_weeks(counts_by_day:, month_start:, today:)
      month_end = month_start.end_of_month
      leading = (month_start.cwday - 1) % 7
      cells = Array.new(leading)
      month_start.upto(month_end) do |date|
        testers = counts_by_day.dig(date, :testers).to_i
        future = date > today
        cells << {
          date: date,
          testers: testers,
          future: future,
          today: date == today,
          tier: future ? nil : Testers.goal_tier(testers)
        }
      end
      trailing = (7 - (cells.size % 7)) % 7
      cells.concat(Array.new(trailing)) if trailing.positive?
      cells.each_slice(7).to_a
    end

    def climbers_goal_met_days(counts_by_day:, month_start:, today:)
      month_end = [ month_start.end_of_month, today ].min
      return 0 if month_end < month_start

      month_start.upto(month_end).count do |date|
        counts_by_day.dig(date, :testers).to_i >= Testers::DAILY_CLIMBERS_GOAL
      end
    end

    def climbers_tier_class(tier)
      case tier
      when :met then "is-goal-met"
      when :partial then "is-goal-partial"
      when :zero then "is-goal-zero"
      else ""
      end
    end
  end
end
