# frozen_string_literal: true

class LifeJourneysController < ApplicationController
  before_action :require_planning_v2

  def new
    @life_areas = current_user.life_areas.v2_selected
    redirect_to life_area_selections_path, alert: t("journeys.need_areas") and return if @life_areas.empty?

    @journey = current_user.life_journeys.new(life_area_id: params[:life_area_id])
  end

  def create
    area = current_user.life_areas.v2_selected.find(params.require(:life_journey)[:life_area_id])
    attrs = params.require(:life_journey).permit(
      :title, :ideal_scene, :current_reality, :next_win, :today_mission, :closer_percent
    )
    journey = Journeys::Create.call(
      user: current_user,
      life_area: area,
      title: attrs[:title].presence || attrs[:ideal_scene].to_s.truncate(80),
      ideal_scene: attrs[:ideal_scene],
      current_reality: attrs[:current_reality],
      next_win: attrs[:next_win],
      closer_percent: attrs[:closer_percent].presence || 30
    )
    Focus::SetJourneys.call(user: current_user, journey_ids: [ journey.id ])
    Missions::EnsureDaily.call(
      user: current_user,
      mission_title: attrs[:today_mission].presence
    )
    redirect_to dashboard_path, notice: t("journeys.created")
  rescue Journeys::Create::Error, Focus::SetJourneys::Error, ActiveRecord::RecordNotFound => e
    redirect_to new_life_journey_path, alert: e.message
  end

  def show
    @journey = current_user.life_journeys.find(params[:id])
    @today_mission = @journey.missions.for_day(Date.current).primary.order(:id).first
  end

  def update
    @journey = current_user.life_journeys.find(params[:id])
    attrs = journey_setup_params

    closer = attrs.delete(:closer_percent)
    attrs.delete(:today_mission)
    if closer.present?
      @journey.gap_percent = (100.0 - closer.to_f).clamp(0, 100).round(2)
    end

    if @journey.update(attrs)
      sync_today_mission_title!
      redirect_to life_journey_path(@journey), notice: t("journeys.setup_saved")
    else
      @today_mission = @journey.missions.for_day(Date.current).primary.order(:id).first
      flash.now[:alert] = @journey.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def journey_setup_params
    params.require(:life_journey).permit(
      :title,
      :purpose,
      :policy,
      :approach,
      :program,
      :next_win,
      :ideal_scene,
      :current_reality,
      :finished_result,
      :closer_percent,
      :today_mission
    )
  end

  def sync_today_mission_title!
    title = params.dig(:life_journey, :today_mission).to_s.strip
    return if title.blank?

    mission = @journey.missions.for_day(Date.current).primary.order(:id).first
    if mission && !mission.completed?
      mission.update!(title: title)
    elsif mission.nil?
      Missions::EnsureDaily.call(user: current_user, mission_title: title)
    end
  end

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path, alert: t("journeys.need_v2")
  end
end
