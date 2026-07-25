class MissionsController < ApplicationController
  def show
    building = current_user.focus_building || current_user.buildings.active.order(:id).first
    unless building
      redirect_to onboarding_path and return if current_user.needs_onboarding?

      redirect_to dashboard_path and return
    end

    @building = building
    @actions = building.today_actions.for_day(Date.current).ordered
    @life_points = current_user.life_points
  end
end
