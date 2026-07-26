# frozen_string_literal: true

class BattleCompletionsController < ApplicationController
  def create
    goal = strategy_root_goal
    before = goal&.progress_percent.to_i

    result = Battles::CompleteDay.call(user: current_user)
    Journeys::SyncClimbFromToday.call(user: current_user)

    after = goal&.reload&.progress_percent.to_i
    if result.ok && after > before
      flash[:mountain_from] = before
      flash[:mountain_to] = after
    end

    if result.ok
      redirect_to dashboard_path, notice: result.message
    else
      redirect_to dashboard_path, alert: result.message
    end
  rescue Missions::Complete::Error => e
    redirect_to dashboard_path, alert: e.message
  end

  private

  def strategy_root_goal
    journey = current_user.primary_focused_journey
    return unless journey

    current_user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
  end
end
