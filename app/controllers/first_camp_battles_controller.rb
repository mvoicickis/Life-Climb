# frozen_string_literal: true

class FirstCampBattlesController < ApplicationController
  before_action :require_planning_v2
  before_action :set_journey

  def create
    project = first_camp_project
    return head :unprocessable_entity if project.blank?

    title = params.require(:title).to_s.strip
    return head :unprocessable_entity if title.blank?

    repeat, weekdays = parse_repeat_params
    return head :unprocessable_entity if repeat == "weekly" && weekdays.empty?

    battle = nil
    ActiveRecord::Base.transaction do
      project.children.select(&:day?).each(&:destroy!)
      battle = current_user.strategy_goals.create!(
        life_area: project.life_area,
        life_journey_id: project.life_journey_id,
        parent: project,
        horizon: "day",
        title: title,
        scheduled_on: Date.current,
        repeat: repeat,
        repeat_weekdays: weekdays.presence,
        position: 0
      )
      Strategy::CascadeToDaily.sync_goal!(user: current_user, goal: battle)
      @journey.clear_first_camp_reveal!
    end

    @project = project.reload
    @plan = @project.parent if @project.parent&.plan?
    @goal = @project.root_goal
    @area = project.life_area
    days = @project.children.select(&:day?).reject(&:holding?)
    helpers.mountain_trail_preload_done_today!(current_user, days)

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to life_journey_path(@journey, open_camp: @project.id), status: :see_other
      end
    end
  rescue ActiveRecord::RecordInvalid
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

  def first_camp_project
    plan = current_user.strategy_goals
      .where(life_journey_id: @journey.id)
      .for_kind("plan")
      .order(:position, :id)
      .first
    return if plan.blank?

    plan.children.for_kind("project").not_holding.order(:position, :id).first
  end

  def parse_repeat_params
    if params[:repeat].to_s == "weekly"
      weekdays = Array(params[:repeat_weekdays]).map(&:to_i).select { |w| (0..6).cover?(w) }.uniq
      return [ "weekly", weekdays ]
    end

    [ "none", nil ]
  end
end
