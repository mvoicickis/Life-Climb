# frozen_string_literal: true

class FirstClimbsController < ApplicationController
  before_action :require_planning_v2

  def create
    journey = current_user.life_journeys.active.find(params.require(:life_journey_id))
    result = Strategy::FirstClimb.call(
      user: current_user,
      journey: journey,
      plan_title: params.require(:plan_title),
      today_action: params.require(:today_action),
      goal: find_destination_goal(journey),
      goal_title: params[:title].to_s.strip.presence
    )

    if result.created?
      flash[:first_climb] = true
      flash[:human_win] = I18n.t("strategy.first_climb.human_ready", action: result.battle.title) if result.battle
      redirect_to dashboard_path, status: :see_other
    else
      # Idempotent retry (double-submit / refresh): land on Today without recreating.
      redirect_to dashboard_path, status: :see_other
    end
  rescue ArgumentError => e
    redirect_to life_journey_path(journey_for_redirect), alert: e.message, status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to life_journey_path(journey_for_redirect),
                alert: e.record.errors.full_messages.to_sentence,
                status: :see_other
  end

  private

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path
  end

  def journey_for_redirect
    current_user.primary_focused_journey || current_user.life_journeys.active.order(:id).first
  end

  def find_destination_goal(journey)
    id = params[:goal_id].presence
    return if id.blank?

    current_user.strategy_goals.for_kind("goal").roots.find_by(
      id: id,
      life_journey_id: journey.id
    )
  end
end
