# frozen_string_literal: true

class CampArrangementsController < ApplicationController
  include MountainTrailHelper
  include StrategyHelper

  before_action :require_planning_v2
  before_action :set_journey
  before_action :set_plan

  def update
    groups = parse_groups(params[:groups])
    Strategy::ArrangeCamps.call(user: current_user, plan: @plan, groups: groups)
    load_trail_context

    respond_to do |format|
      format.turbo_stream
      format.json { head :ok }
      format.html { redirect_to life_journey_path(@journey, goal_id: @goal&.id, plan_id: @plan.id), status: :see_other }
    end
  rescue Strategy::ArrangeCamps::Invalid
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.json { head :unprocessable_entity }
      format.html { head :unprocessable_entity }
    end
  end

  private

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to dashboard_path, alert: t("strategy.need_v2"), status: :see_other
  end

  def set_journey
    @journey = current_user.life_journeys.active.find(params[:life_journey_id])
  end

  def set_plan
    @plan = current_user.strategy_goals.find_by(id: params[:plan_id], horizon: "plan")
    return if @plan.present?

    head :unprocessable_entity
  end

  def parse_groups(raw)
    return [] if raw.blank?

    entries =
      if raw.is_a?(Array)
        raw
      elsif raw.respond_to?(:to_unsafe_h)
        raw.to_unsafe_h.sort_by { |key, _| key.to_i }.map(&:last)
      else
        raw.sort_by { |key, _| key.to_i }.map(&:last)
      end

    entries.map do |entry|
      hash = entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h : entry
      { camp_ids: Array(hash[:camp_ids] || hash["camp_ids"]).map(&:to_i) }
    end
  end

  def load_trail_context
    @goal = @plan.root_goal
    @trail = Strategy::Trail.for(plan: @plan.reload)
    all_projects = mountain_trail_all_projects(@trail)
    @arrange_projects = all_projects
    @projects = mountain_trail_projects(@trail)
    @current_project = mountain_trail_current_project(@projects)
    base_due_battles = mountain_trail_base_due_battles(@projects)
    root = @goal
    all_today = root.present? ? Strategy::Progress.battles_under(root).select { |b| b.scheduled_on == Date.current } : []
    won_today = all_today.count { |b| b.completed_at.present? }
    @today_card = mountain_trail_dock_card(
      projects: @projects,
      open_battles: base_due_battles,
      won_today: won_today,
      journey: @journey
    )
    @open_stage = mountain_trail_open_stage(@arrange_projects)
  end
end
