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
    @daily_todos = current_user.daily_todos
      .for_day(Date.current)
      .includes(strategy_goal: [ :practice_tasks, :parent ])
      .ordered
    @open_todos = @daily_todos.reject(&:completed?)
    @done_todos = @daily_todos.select(&:completed?)
    @strategy_goal = current_user.strategy_goals.for_area(@journey.life_area_id).for_kind("goal").roots.first
    retire_plan_route_if_needed!
    # Empty spine: never dead-end on "Plan Your Route" — show the 60s first-climb coach.
    @first_climb_needed = @strategy_goal.present? && @strategy_goal.children.for_kind("plan").none?
    @show_plan_route = @first_climb_needed || plan_route_pending?
    # Only pending missions belong in Today's Battle. "replaced" scaffolding
    # (e.g. Plan Your Route after first climb) must not reappear beside real actions.
    @include_mission_in_battle = !@show_plan_route && @mission.present? && @mission.status == "pending"
    @battle_reward = @open_todos.sum { |t| t.lp_reward.to_i }
    @battle_reward += @mission.lp_reward if @include_mission_in_battle
    @battle_open_count = @open_todos.size + (@include_mission_in_battle ? 1 : 0)
    @battle_day_full = @daily_todos.size >= GameRules::MAX_DAILY_TODOS
    @targets = @journey.journey_targets.active.ordered.to_a
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
    @battle_total_count = @daily_todos.size + (@include_mission_in_battle ? 1 : 0)
    @project_check = Strategy::ProjectCheckQueue.next_for(user: current_user, session: session)
    @battle_angle_project =
      if @project_check
        nil
      else
        Strategy::BattleAngleQueue.project_for(user: current_user, session: session)
      end
    @battle_angles =
      @battle_angle_project ? Strategy::BattleAngles.for(project: @battle_angle_project) : []
    @adventure_year = (@strategy_goal&.due_on || Strategy::YearCycle.default_goal_due).year
    Climb::Streak.reconcile!(user: current_user)
    @climb_streak = Climb::Streak.status(user: current_user)
    @habits = current_user.habits.active.on_home.ordered.includes(:daily_logs, :completions)
    render "dashboard/show_v2"
  end

  def plan_route_pending?
    return false if @journey.blank?
    return false unless @journey.setup_flag(Onboarding::Run::ROUTE_FLAG) == "pending"
    return false if strategy_day_battles?

    @mission.present? && !@mission.completed?
  end

  def strategy_day_battles?
    return true if @daily_todos.any? { |t| t.tag.to_s == "strategy" || t.strategy_goal_id.present? }
    return false if @strategy_goal.blank?

    Strategy::Progress.battles_under(@strategy_goal).any?
  end

  def retire_plan_route_if_needed!
    return if @journey.blank?
    return unless @journey.setup_flag(Onboarding::Run::ROUTE_FLAG) == "pending"
    return unless strategy_day_battles?

    flags = (@journey.setup_flags.presence || {}).stringify_keys.merge(Onboarding::Run::ROUTE_FLAG => "done")
    @journey.update_columns(setup_flags: flags, updated_at: Time.current)
    @journey.setup_flags = flags

    if @mission.present? && !@mission.completed?
      @mission.update!(status: "replaced")
      @mission = nil
    end
  end
end
