class DashboardController < ApplicationController
  def show
    promote_legacy_tree_users!
    show_v2
  end

  private

  # Old accounts still on planning_version 1 get the Life Tree Home.
  # Product is one-mountain v2 everywhere — graduate them on visit.
  def promote_legacy_tree_users!
    return if current_user.planning_v2?

    current_user.update!(planning_version: 2)
  end

  def show_v2
    @journey = current_user.primary_focused_journey
    unless @journey
      if current_user.life_journeys.where(status: "completed").exists?
        redirect_to next_mountain_path and return
      end
      if current_user.life_journeys.active.any?
        redirect_to life_journey_path(current_user.life_journeys.active.order(:id).first) and return
      end
      redirect_to(current_user.onboarding_completed? ? new_life_journey_path : v2_onboarding_path) and return
    end

    @mission = @journey.missions.for_day(Date.current).primary.incomplete.order(:id).first ||
               @journey.missions.for_day(Date.current).primary.order(:id).first
    @life_points = current_user.life_points
    @daily_todos = current_user.daily_todos.for_day(Date.current).ordered
    @open_todos = @daily_todos.reject(&:completed?)
    @done_todos = @daily_todos.select(&:completed?)
    @include_mission_in_battle = @mission.present? && !@mission.completed?
    @battle_reward = @open_todos.sum { |t| t.lp_reward.to_i }
    @battle_reward += @mission.lp_reward if @include_mission_in_battle
    @battle_open_count = @open_todos.size + (@include_mission_in_battle ? 1 : 0)
    @battle_day_full = @daily_todos.size >= GameRules::MAX_DAILY_TODOS
    @targets = @journey.journey_targets.active.ordered.to_a
    @strategy_goal = current_user.strategy_goals.for_area(@journey.life_area_id).for_kind("goal").roots.first
    @closer =
      if @strategy_goal
        @strategy_goal.progress_percent.to_i
      else
        @journey.closer_percent.round
      end
    @mountain = Strategy::Mountain.for(goal: @strategy_goal)
    @strategy_handoff = Strategy::Handoff.for(user: current_user, journey: @journey)
    @upcoming_battle = Strategy::UpcomingBattle.for(user: current_user, journey: @journey)
    @battle_celebrate = flash[:battle_celebrate].present?
    @battle_total_count = @daily_todos.size + (@mission.present? ? 1 : 0)
    @project_check = Strategy::ProjectCheckQueue.next_for(user: current_user, session: session)
    render "dashboard/show_v2"
  end
end
