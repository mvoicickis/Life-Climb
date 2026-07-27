# frozen_string_literal: true

# Explicit Strategy-Space AI help. Never writes Goals/Plans — suggestions only.
class StrategyHelpsController < ApplicationController
  before_action :require_planning_v2

  def create
    @goal = params[:goal].to_s.strip
    @ideal_scene = params[:ideal_scene].to_s.strip
    @current_reality = params[:current_reality].to_s.strip
    @life_area = params[:life_area].to_s.strip
    @goal_title = params[:goal_title].to_s.strip
    @plan_title = params[:plan_title].to_s.strip
    @project_title = params[:project_title].to_s.strip
    @horizon = params[:horizon].to_s.strip.presence_in(Ai::StrategyService::HORIZONS) || Ai::StrategyService::DEFAULT_HORIZON
    @journey_id = params[:life_journey_id].presence
    @parent_id = params[:parent_id].presence
    @life_area_id = params[:life_area_id].presence
    @target_input = params[:target_input].to_s.strip.presence
    @accept_as = params[:accept_as].presence_in(%w[plan fill ideas]) || "fill"

    if @goal.blank?
      @error = t("strategy.help.goal_required")
      @result = nil
    else
      context = {
        ideal_scene: @ideal_scene.presence,
        current_reality: @current_reality.presence,
        life_area: @life_area.presence,
        goal_title: @goal_title.presence,
        plan_title: @plan_title.presence,
        project_title: @project_title.presence
      }.compact
      @result = Ai::StrategyService.call(goal: @goal, horizon: @horizon, context:)
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
