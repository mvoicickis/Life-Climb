# frozen_string_literal: true

module Dashboard
  # Shared Today battle-surface assigns for DashboardController#show_v2 and
  # commitment_gap turbo refreshes — keeps plan-route / timeline / anytime in sync.
  module TodaySurface
    extend ActiveSupport::Concern

    private

    # Assumes @journey is already set. When reconcile: true, runs streak/shield/miss
    # settlement then reloads todos (full Today page). Stream refreshes pass false
    # for a lighter rebuild from current DB state after a local create.
    def assign_today_battle_surface!(reconcile: true)
      @mission = @journey.missions.for_day(Date.current).primary.incomplete.order(:id).first ||
                 @journey.missions.for_day(Date.current).primary.order(:id).first
      @daily_todos = current_user.daily_todos
        .for_day(Date.current)
        .includes(strategy_goal: [ :practice_tasks, :parent ])
        .ordered
      @open_todos = @daily_todos.reject(&:completed?)
      @done_todos = @daily_todos.select(&:completed?)
      @strategy_goal = current_user.strategy_goals.for_area(@journey.life_area_id).for_kind("goal").roots.first
      retire_plan_route_if_needed!
      @first_climb_needed = @strategy_goal.present? && @strategy_goal.children.for_kind("plan").none?
      @show_plan_route = @first_climb_needed || plan_route_pending?
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

      if reconcile
        Climb::Streak.reconcile!(user: current_user)
        Today::DayShield.reconcile!(user: current_user)
        Today::MissSettlement.apply!(user: current_user)
        @daily_todos = current_user.daily_todos
          .for_day(Date.current)
          .includes(:life_point_ledgers, strategy_goal: [ :practice_tasks, :parent ])
          .ordered
        @open_todos = @daily_todos.reject(&:completed?)
        @done_todos = @daily_todos.select(&:completed?)
        @battle_open_count = @open_todos.size + (@include_mission_in_battle ? 1 : 0)
        @battle_total_count = @daily_todos.size + (@include_mission_in_battle ? 1 : 0)
      end

      @timeline = Today::Timeline.build(user: current_user, todos: @open_todos)
      @habits = current_user.habits.active.on_home.ordered.includes(:daily_logs, :completions)
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
end
