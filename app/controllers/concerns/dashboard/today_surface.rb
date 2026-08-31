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
      sync_today_battles! unless read_only_impersonation?

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
      @first_climb_needed = @strategy_goal.present? && @strategy_goal.children.for_kind("plan").not_holding.none?
      @show_plan_route = @first_climb_needed || plan_route_pending?
      @include_mission_in_battle = !@show_plan_route && @mission.present? && @mission.status == "pending"
      @battle_reward = @open_todos.sum { |t| t.lp_reward.to_i }
      @battle_reward += @mission.lp_reward if @include_mission_in_battle
      @battle_open_count = @open_todos.size + (@include_mission_in_battle ? 1 : 0)
      @battle_day_full = @open_todos.size >= GameRules::MAX_DAILY_TODOS
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
      @adventure_year = (@strategy_goal&.due_on || Strategy::YearCycle.default_goal_due).year

      if reconcile && !read_only_impersonation?
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

      assign_battles_waiting_count!

      @timeline = Today::Timeline.build(user: current_user, todos: @open_todos)
      @habits = current_user.habits.active.on_home.ordered.includes(:daily_logs, :completions)
    end

    def assign_battlefield_prompt!
      return unless @battlefield_health&.all_clear?

      @battlefield_prompt = Today::BattlefieldPrompt.call(
        health: @battlefield_health,
        project_check: @project_check,
        battle_angle_project: nil,
        battle_angles: [],
        battles_waiting_count: @battles_waiting_count,
        upcoming_battle: @upcoming_battle
      )
    end

    def assign_end_of_day!
      habits_gate = GameRules.habits_enabled?
      @end_of_day_ready = Today::EndOfDay.ready?(
        health: @battlefield_health,
        habits: @habits,
        habits_gate_enabled: habits_gate
      )
      day_closed = Today::BattlefieldDay.ended?(session)
      return unless @end_of_day_ready || day_closed

      @end_of_day_camps = Today::EndOfDay.open_camps(strategy_goal: @strategy_goal)
      @tomorrow_battles = Today::EndOfDay.tomorrow_battles(user: current_user, journey: @journey)
      @eod_step = Today::EodFlow.step(
        session: session,
        end_of_day_ready: @end_of_day_ready,
        day_closed: day_closed
      )
    end

    def assign_today_habit_stream!
      @journey = current_user.primary_focused_journey
      return if @journey.blank?

      assign_today_battle_surface!(reconcile: false)
      @battlefield_health = Today::BattlefieldHealth.call(
        open_count: @battle_open_count,
        total_count: @battle_total_count
      )
      @battlefield_day_ended = Today::BattlefieldDay.ended?(session)
      @climb_streak = Climb::Streak.status(user: current_user)
      assign_end_of_day!
      @recap_share = helpers.end_of_day_share_text(@battlefield_health)
    end

    def sync_today_battles!
      return if @journey.blank?
      return if read_only_impersonation?

      Strategy::CascadeToDaily.call(
        user: current_user,
        life_area: @journey.life_area,
        from: Date.current,
        to: Date.current
      )
    end

    def assign_battles_waiting_count!
      @battles_waiting_count =
        if @journey.blank?
          0
        else
          Today::BattlesWaiting.count(
            user: current_user,
            life_area: @journey.life_area,
            on: Date.current
          )
        end
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
      return if read_only_impersonation?
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
