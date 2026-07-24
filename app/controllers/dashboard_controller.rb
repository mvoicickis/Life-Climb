class DashboardController < ApplicationController
  def show
    @trackers = current_user.home_trackers
    @ups = @trackers.count { |tracker| tracker.vs_yesterday == :up }
    @levels = @trackers.count { |tracker| tracker.vs_yesterday == :level }
    @downs = @trackers.count { |tracker| tracker.vs_yesterday == :down }
    @grid_count = [ @trackers.size, 1 ].max
  end
end
