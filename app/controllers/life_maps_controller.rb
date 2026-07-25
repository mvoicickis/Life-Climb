class LifeMapsController < ApplicationController
  def show
    if current_user.planning_v2?
      @life_areas = current_user.selected_life_areas
      @journey = current_user.primary_focused_journey
      @focus_area_id = @journey&.life_area_id
      @life_points = current_user.life_points
      @alive_level = current_user.alive_level
      @gap = current_user.overall_gap_percent
      render "life_maps/show_v2" and return
    end

    LifePointsDecay.new(current_user).call

    @dream = current_user.active_dream
    unless @dream
      redirect_to onboarding_path and return if current_user.needs_onboarding?

      redirect_to dashboard_path and return
    end

    @dream.ensure_life_areas!
    @life_areas = @dream.life_areas.tree
    @life_area = current_user.focus_life_area
    @life_points = current_user.life_points
    @alive_level = current_user.alive_level
  end
end
