class DashboardController < ApplicationController
  def show
    @trackers = current_user.home_trackers
    @wins = @trackers.count { |tracker| tracker.vs_yesterday == :up }
    @needs_work = @trackers.count { |tracker| tracker.vs_yesterday == :not_up }
    @grid_count = [ @trackers.size, 1 ].max
  end
end
