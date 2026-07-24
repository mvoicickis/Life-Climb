class DashboardController < ApplicationController
  def show
    @trackers = current_user.home_trackers
    statuses = @trackers.map(&:status)
    @good = statuses.count { |status| %i[better perfect].include?(status) }
    @same = statuses.count { |status| status == :same }
    @off = statuses.count { |status| %i[worse too_low too_high].include?(status) }
    @grid_count = [ @trackers.size, 1 ].max
  end
end
