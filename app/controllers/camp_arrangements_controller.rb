# frozen_string_literal: true

class CampArrangementsController < ApplicationController
  include MountainTrailHelper
  include StrategyHelper

  before_action :require_planning_v2
  before_action :set_journey
  before_action :set_plan, only: %i[update stage_camp]

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

  def reopen
    camp = find_journey_camp(params[:camp_id])
    return head :not_found if camp.blank?

    @plan = camp.parent
    return head :not_found if @plan.blank? || !@plan.plan?

    Strategy::ReopenPlanCamp.call(user: current_user, camp: camp)
    @focus_stage = camp.reload.stage.to_i
    load_trail_context

    respond_to do |format|
      format.turbo_stream { render :reopen }
      format.html { redirect_to life_journey_path(@journey, goal_id: @goal&.id, plan_id: @plan.id), status: :see_other }
    end
  rescue Strategy::ReopenPlanCamp::Invalid
    head :unprocessable_entity
  end

  def stage_camp
    title = params[:title].to_s.strip
    return head :unprocessable_entity if title.blank?

    camp = Strategy::CreatePlanStageCamp.call(
      user: current_user,
      plan: @plan,
      stage: params[:stage],
      title: title
    )
    @focus_stage = camp.stage.to_i
    load_trail_context

    respond_to do |format|
      format.turbo_stream { render :stage_camp }
      format.html { redirect_to life_journey_path(@journey, goal_id: @goal&.id, plan_id: @plan.id), status: :see_other }
    end
  rescue Strategy::CreatePlanStageCamp::Invalid, Strategy::PlaceCampOnStage::Invalid
    head :unprocessable_entity
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
    @plan = current_user.strategy_goals.for_kind("plan").find_by(id: params[:plan_id])
    return head :not_found if @plan.blank?

    owned =
      @plan.life_journey_id == @journey.id ||
      (@plan.life_journey_id.blank? && @plan.life_area_id == @journey.life_area_id)
    return if owned

    head :not_found
  end

  def find_journey_camp(camp_id)
    camp = current_user.strategy_goals.for_kind("project").not_holding.find_by(id: camp_id)
    return nil if camp.blank?

    owned =
      camp.life_journey_id == @journey.id ||
      (camp.life_journey_id.blank? && camp.life_area_id == @journey.life_area_id)
    owned ? camp : nil
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
