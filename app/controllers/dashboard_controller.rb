class DashboardController < ApplicationController
  PRIORITY_LIMIT = 3

  def show
    @trackers = current_user.home_trackers
    statuses = @trackers.map(&:status)
    @good = statuses.count { |status| %i[better perfect].include?(status) }
    @same = statuses.count { |status| status == :same }
    @off = statuses.count { |status| %i[worse too_low too_high].include?(status) }

    insights = DashboardInsights.new(current_user, trackers: @trackers)
    @streak = insights.streak_days
    @week_series = insights.week_series
    @week_percent = insights.week_percent
    @focus_tips = insights.focus_tips
    @celebrations = insights.celebrations
    @daily_quote = daily_quote

    prioritized = insights.prioritized_trackers
    @priority_trackers = prioritized.first(PRIORITY_LIMIT)
    @more_trackers = prioritized.drop(PRIORITY_LIMIT)
    @grid_count = [ @priority_trackers.size, 1 ].max
  end

  private

  def daily_quote
    quotes = Array(I18n.t("dashboard.quotes", default: [ I18n.t("dashboard.quote") ]))
    quotes = [ I18n.t("dashboard.quote") ] if quotes.empty?
    quotes[Date.current.yday % quotes.length]
  end
end
