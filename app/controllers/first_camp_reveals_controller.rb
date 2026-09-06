# frozen_string_literal: true

class FirstCampRevealsController < ApplicationController
  before_action :require_planning_v2
  before_action :set_journey

  def update
    return head :no_content unless @journey.first_camp_reveal_pending?

    @journey.clear_first_camp_reveal!
    @project = first_camp_project
    @plan = @project&.parent if @project&.parent&.plan?
    @goal = @project&.root_goal
    @area = @project&.life_area || @journey.life_area

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

  def first_camp_project
    plan = current_user.strategy_goals
      .where(life_journey_id: @journey.id)
      .for_kind("plan")
      .order(:position, :id)
      .first
    return if plan.blank?

    plan.children.for_kind("project").not_holding.order(:position, :id).first
  end
end
