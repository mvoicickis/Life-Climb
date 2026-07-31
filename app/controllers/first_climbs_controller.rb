# frozen_string_literal: true

class FirstClimbsController < ApplicationController
  before_action :require_planning_v2

  def create
    journey = current_user.life_journeys.active.find(params.require(:life_journey_id))
    goal = find_destination(journey)
    result = Strategy::FirstClimb.call(
      user: current_user,
      journey: journey,
      goal: goal,
      plan_title: params.require(:plan_title),
      today_action: params.require(:today_action)
    )

    flash[:first_climb] = true
    flash[:human_win] = I18n.t("strategy.first_climb.human_ready", action: result.battle.title)
    redirect_to dashboard_path, notice: I18n.t("strategy.first_climb.ready_notice"), status: :see_other
  rescue ArgumentError => e
    redirect_to life_journey_path(journey_for_redirect, goal_id: params[:goal_id].presence),
                alert: e.message, status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to life_journey_path(journey_for_redirect, goal_id: params[:goal_id].presence),
                alert: e.record.errors.full_messages.to_sentence,
                status: :see_other
  end

  private

  def find_destination(journey)
    return if params[:goal_id].blank?

    current_user.strategy_goals
      .for_area(journey.life_area_id)
      .for_kind("goal")
      .roots
      .find_by(id: params[:goal_id])
  end

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path
  end

  def journey_for_redirect
    current_user.primary_focused_journey || current_user.life_journeys.active.order(:id).first
  end
end
