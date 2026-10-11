# frozen_string_literal: true

class FirstCampBattlesController < ApplicationController
  before_action :require_planning_v2
  before_action :set_journey

  def create
    unless @journey.first_camp_reveal_pending?
      log_first_camp_failure("reveal_not_pending")
      return render_stale_journey
    end

    project = first_camp_project
    if project.blank?
      log_first_camp_failure("missing_camp")
      return render_stale_journey
    end

    title = params.fetch(:title, "").to_s.strip
    if title.blank?
      log_first_camp_failure("blank_title")
      return render_first_camp_error(t("strategy.rpg.trail.first_camp_reveal.blank_title"))
    end

    repeat, weekdays = parse_repeat_params
    if repeat == "weekly" && weekdays.empty?
      log_first_camp_failure("weekly_without_weekdays")
      return render_first_camp_error(t("strategy.rpg.trail.first_camp_reveal.not_saved"))
    end

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
      @journey.set_first_camp_win_nudge!
    end

    @project = project.reload
    @plan = @project.parent if @project.parent&.plan?
    @goal = @project.root_goal
    @area = project.life_area
    days = @project.children.select(&:day?).reject(&:holding?)
    helpers.mountain_trail_preload_done_today!(current_user, days)
    trail = Strategy::Trail.for(plan: @plan)
    @sheet_camps = helpers.mountain_trail_all_projects(trail)

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to life_journey_path(@journey, open_camp: @project.id), status: :see_other
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    log_first_camp_failure("record_invalid", detail: e.record.errors.full_messages.join(", "))
    render_first_camp_error(t("strategy.rpg.trail.first_camp_reveal.not_saved"))
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
    @journey.first_camp_reveal_project
  end

  def parse_repeat_params
    if params[:repeat].to_s == "weekly"
      weekdays = Array(params[:repeat_weekdays]).map(&:to_i).select { |w| (0..6).cover?(w) }.uniq
      return [ "weekly", weekdays ]
    end

    [ "none", nil ]
  end

  def log_first_camp_failure(reason, detail: nil)
    message = "[first_camp_battle] #{reason} user_id=#{current_user.id} journey_id=#{@journey.id}"
    message = "#{message} #{detail}" if detail.present?
    Rails.logger.warn(message)
  end

  def render_stale_journey
    respond_to do |format|
      format.turbo_stream { render :stale, status: :unprocessable_entity }
      format.html { redirect_to life_journey_path(@journey), status: :see_other }
    end
  end

  def render_first_camp_error(message)
    @error_message = message
    respond_to do |format|
      format.turbo_stream { render :error, status: :unprocessable_entity }
      format.html { head :unprocessable_entity }
    end
  end
end
