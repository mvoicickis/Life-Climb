class DashboardController < ApplicationController
  def show
    @building = current_user.focus_building || current_user.buildings.active.order(:id).first
    unless @building
      redirect_to onboarding_path and return if current_user.needs_onboarding?
      redirect_to life_points_path and return
    end

    @dream = @building.dream
    @goal = @building.goal
    @step = @building.step
    @actions = @building.today_actions.for_day(Date.current).ordered
    @rhythms = current_user.habits.active.on_home.ordered.limit(3)
    @latest_finished = current_user.finished_products.newest_first.first
    @life_points = current_user.life_points
  end
end
