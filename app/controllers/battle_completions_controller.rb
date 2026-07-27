# frozen_string_literal: true

class BattleCompletionsController < ApplicationController
  def create
    goal = current_strategy_goal
    result = Battles::CompleteDay.call(user: current_user)
    Journeys::SyncClimbFromToday.call(user: current_user)
    if result.ok
      streak = Climb::Streak.touch!(user: current_user)
      Strategy::ProjectCheckQueue.enqueue(session: session, project_ids: result.project_check_ids)
      flash[:ap_gained] = result.awarded
      flash[:battle_celebrate] = true
      flash[:climb_reward] = Climb::Reward.for_battle(
        user: current_user,
        awarded: result.awarded,
        goal: goal,
        streak_days: streak.days
      )
      redirect_to dashboard_path, notice: result.message
    else
      redirect_to dashboard_path, alert: result.message
    end
  rescue Missions::Complete::Error => e
    redirect_to dashboard_path, alert: e.message
  end

  private

  def current_strategy_goal
    journey = current_user.primary_focused_journey
    return unless journey

    current_user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
  end
end
