# frozen_string_literal: true

# Thin UI shell around Strategy::CompanionGuide::Engine (PR2).
# Entry is temporary via Settings; Mountain/Today polish is PR4.
class CompanionGuidesController < ApplicationController
  before_action :require_planning_v2
  before_action :require_journey!

  def show
    @step = Strategy::CompanionGuide::Engine.current(user: current_user, journey: @journey)
    if @step.blank?
      redirect_to fallback_path, alert: t("strategy.companion_guide.shell.need_goal"), status: :see_other
    end
  end

  def create
    value = params.require(:value)
    result = Strategy::CompanionGuide::Engine.answer!(
      user: current_user,
      journey: @journey,
      value: value
    )
    flash[:companion_ack] = result.ack
    redirect_to companion_guide_path, status: :see_other
  rescue ArgumentError, ActionController::ParameterMissing
    redirect_to companion_guide_path, alert: t("strategy.companion_guide.shell.bad_answer"), status: :see_other
  end

  private

  def require_journey!
    @journey = current_user.primary_focused_journey
    return if @journey.present?

    redirect_to fallback_path, alert: t("strategy.companion_guide.shell.need_journey"), status: :see_other
  end

  def fallback_path
    journey = current_user.primary_focused_journey
    journey ? life_journey_path(journey) : dashboard_path
  end

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path
  end
end
