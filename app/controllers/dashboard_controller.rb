class DashboardController < ApplicationController
  def show
    @trackers = current_user.home_trackers
    @ups = @trackers.count { |tracker| %i[up ok].include?(tracker.status) }
    @levels = @trackers.count { |tracker| tracker.status == :level }
    @downs = @trackers.count { |tracker| %i[down off].include?(tracker.status) }
    @grid_count = [ @trackers.size, 1 ].max
  end
end
