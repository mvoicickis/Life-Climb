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
    @life_points = current_user.life_points
    @daily_todos = current_user.daily_todos.for_day(Date.current).ordered
    @include_mission_in_battle = @mission.present? && !@mission.completed?
    @battle_reward = @daily_todos.incomplete.sum { |t| t.lp_reward.to_i }
    @battle_reward += @mission.lp_reward if @include_mission_in_battle
    @battle_open_count = @daily_todos.incomplete.count + (@include_mission_in_battle ? 1 : 0)
    @project_title = @journey.climb_card_title
    @project_progress = [ @closer, 95 ].min
    @milestones = @journey.milestones_list.first(3)
    @targets = @journey.journey_targets.active.ordered.to_a
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
