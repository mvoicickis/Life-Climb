# frozen_string_literal: true

module LifePointsHelper
  def stats_week_bar_heights(counts)
    max = counts.map(&:to_i).max.to_i
    return counts.map { 0 } if max <= 0

    counts.map do |count|
      next 0 if count.to_i <= 0

      [ (count.to_f / max * 100).round, 8 ].max
    end
  end

  def stats_calendar_weeks(calendar:, today:, battle_wins:)
    month_start = calendar[:month_start]
    month_end = calendar[:month_end]
    counts = calendar[:counts_by_day]
    leading = (month_start.cwday - 1) % 7
    cells = Array.new(leading)
    month_start.upto(month_end) do |date|
      wins = counts[date].to_i
      cells << {
        date: date,
        wins: wins,
        tier: battle_wins.calendar_tier(wins),
        today: date == today
      }
    end
    trailing = (7 - (cells.size % 7)) % 7
    cells.concat(Array.new(trailing)) if trailing.positive?
    cells.each_slice(7).to_a
  end

  def stats_month_param(date)
    date.strftime("%Y-%m")
  end

  def stats_calendar_nav_url(month_date)
    life_points_path(stats_month: stats_month_param(month_date))
  end
end
