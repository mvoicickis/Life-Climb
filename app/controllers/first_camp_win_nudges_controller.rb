# frozen_string_literal: true

class FirstCampWinNudgesController < ApplicationController
  before_action :require_planning_v2
  before_action :set_journey

  def update
    project = pinned_camp_project
    return head :no_content if project.blank?

    @journey.clear_first_camp_win_nudge!
    @project = project
    @plan = @project.parent if @project.parent&.plan?
    @goal = @project.root_goal
    @area = @project.life_area || @journey.life_area
    days = @project.children.select(&:day?).reject(&:holding?)
    helpers.mountain_trail_preload_done_today!(current_user, days)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to life_journey_path(@journey), status: :see_other }
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

  def pinned_camp_project
    camp_id = @journey.first_camp_pinned_camp_id
    return if camp_id.blank?

    current_user.strategy_goals
      .where(life_journey_id: @journey.id)
      .for_kind("project")
      .not_holding
      .find_by(id: camp_id)
  end
end
