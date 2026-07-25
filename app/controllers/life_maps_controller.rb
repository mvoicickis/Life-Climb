class LifeMapsController < ApplicationController
  def show
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
