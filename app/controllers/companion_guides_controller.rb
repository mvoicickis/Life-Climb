# frozen_string_literal: true

# Thin UI shell around Strategy::CompanionGuide::Engine.
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
    # Rails 8 params.require treats blank/whitespace as missing — use raw fetch
    # so Writer can raise the specific blank_title message for free-text steps.
    unless params.key?(:value) || params.key?("value")
      return render_answer_error(
        t("strategy.companion_guide.shell.bad_answer"),
        attempted_value: ""
      )
    end

    value = params[:value]
    result = Strategy::CompanionGuide::Engine.answer!(
      user: current_user,
      journey: @journey,
      value: value
    )
    flash[:companion_ack] = result.ack
    redirect_to companion_guide_path, status: :see_other
  rescue ArgumentError => e
    render_answer_error(
      e.message.presence || t("strategy.companion_guide.shell.bad_answer"),
      attempted_value: params[:value].to_s
    )
  end

  private

  def render_answer_error(message, attempted_value:)
    @error = message
    @attempted_value = attempted_value
    @step = Strategy::CompanionGuide::Engine.current(user: current_user, journey: @journey)
    if @step.blank?
      redirect_to fallback_path, alert: t("strategy.companion_guide.shell.need_goal"), status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

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
