class DashboardController < ApplicationController
  def show
    if current_user.planning_v2?
      show_v2
    else
      show_v1
    end
  end

  private

  def show_v2
    @journey = current_user.primary_focused_journey
    unless @journey
      if current_user.life_journeys.where(status: "completed").exists?
        redirect_to next_mountain_path and return
      end
      redirect_to(current_user.life_journeys.active.any? ? life_journey_path(current_user.life_journeys.active.order(:id).first) : new_life_journey_path) and return
    end

    @mission = @journey.missions.for_day(Date.current).primary.incomplete.order(:id).first ||
               @journey.missions.for_day(Date.current).primary.order(:id).first
    @closer = @journey.closer_percent.round
    default_aspect = params[:aspect].presence ||
                     @mission&.aspect_key.presence ||
                     @journey.life_area.key
    @selected_aspect = LifeArea::HOME_ASPECT_KEYS.include?(default_aspect) ? default_aspect : LifeArea::HOME_ASPECT_KEYS.first
    @daily_todos = current_user.daily_todos.for_day(Date.current).ordered
    render "dashboard/show_v2"
  end

  def show_v1
    LifePointsDecay.new(current_user).call
    current_user.reload

    @building = current_user.focus_building || current_user.buildings.active.order(:id).first
    unless @building
      redirect_to onboarding_path and return if current_user.needs_onboarding?
      redirect_to life_points_path and return
    end

    @dream = @building.dream
    @dream.ensure_life_areas!
    @life_areas = @dream.life_areas.tree
    @life_area = @building.goal.life_area || current_user.focus_life_area
    @goal = @building.goal
    @step = @building.step
    @actions = @building.today_actions.for_day(Date.current).ordered
    @life_points = current_user.life_points
    @lp_today = current_user.ledger_points_today
    @alive_level = current_user.alive_level
  end
end
