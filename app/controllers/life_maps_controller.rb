class LifeMapsController < ApplicationController
  def show
    current_user.update!(planning_version: 2) unless current_user.planning_v2?

    @life_areas = current_user.selected_life_areas
    @journey = current_user.primary_focused_journey
    @focus_area_id = @journey&.life_area_id
    @life_points = current_user.life_points
    @alive_level = current_user.alive_level
    @gap = current_user.overall_gap_percent

    if @life_areas.blank?
      redirect_to(current_user.onboarding_completed? ? dashboard_path : v2_onboarding_path) and return
    end

    render "life_maps/show_v2"
  end
end
