class DashboardController < ApplicationController
  def show
    @trackers = current_user.home_trackers
    statuses = @trackers.map(&:status)
    @good = statuses.count { |status| %i[better perfect].include?(status) }
    @same = statuses.count { |status| status == :same }
    @off = statuses.count { |status| %i[worse too_low too_high].include?(status) }
    @grid_count = [ @trackers.size, 1 ].max

    insights = DashboardInsights.new(current_user, trackers: @trackers)
    @streak = insights.streak_days
    @week_series = insights.week_series
    @week_percent = insights.week_percent
    @focus_tips = insights.focus_tips
  end
end
