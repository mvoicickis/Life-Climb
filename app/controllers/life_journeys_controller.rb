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
  end

  private

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path, alert: t("journeys.need_v2")
  end
end
