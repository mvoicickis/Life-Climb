class DashboardController < ApplicationController
  include Dashboard::TodaySurface

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

    assign_today_battle_surface!(reconcile: true)

    @battle_celebrate = flash[:battle_celebrate].present?
    @life_points = current_user.reload.life_points
    @climb_streak = Climb::Streak.status(user: current_user)
    @day_shield = Today::DayShield.status(user: current_user)
    @commitment = Today::Commitment.touch_met_streak!(user: current_user, journey: @journey)
    @commitment_level_up = Today::Commitment.suggest_level_up?(journey: @journey)
    @next_action = Strategy::NextAction.for(
      user: current_user,
      session: session,
      journey: @journey
    )
    # Read-only overshoot display — never sync! / award on GET.
    day_pct = Today::DayPercent.call(
      user: current_user,
      habits: @habits,
      todos: @daily_todos
    )
    @day_percent = day_pct.percent
    @overshoot_bonus = current_user.day_overshoot_bonuses.find_by(on_date: Date.current)
    render "dashboard/show_v2"
  end
end
