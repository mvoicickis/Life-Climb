# frozen_string_literal: true

# Explicit Strategy-Space AI help. Never writes Goals/Plans — suggestions only.
class StrategyHelpsController < ApplicationController
  before_action :require_planning_v2

  def create
    @goal = params[:goal].to_s.strip
    @ideal_scene = params[:ideal_scene].to_s.strip
    @current_reality = params[:current_reality].to_s.strip
    @life_area = params[:life_area].to_s.strip
    @journey_id = params[:life_journey_id].presence
    @parent_id = params[:parent_id].presence
    @life_area_id = params[:life_area_id].presence
    @accept_as = params[:accept_as].presence_in(%w[plan fill ideas]) || "fill"

    if @goal.blank?
      @error = t("strategy.help.goal_required")
      @result = nil
    else
      context = {
        ideal_scene: @ideal_scene.presence,
        current_reality: @current_reality.presence,
        life_area: @life_area.presence
      }.compact
      @result = Ai::StrategyService.call(goal: @goal, context:)
      @error = nil
    end

    respond_to do |format|
      format.turbo_stream
      format.html { render partial: "strategy_helps/panel", layout: false }
    end
  rescue Ai::Error => e
    @result = nil
    @error = e.message
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
      format.html { render partial: "strategy_helps/panel", layout: false, status: :unprocessable_entity }
    end
  end

  private

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path
  end
end
