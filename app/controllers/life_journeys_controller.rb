class LifeJourneysController < ApplicationController
  before_action :require_planning_v2

  def new
    @life_areas = current_user.life_areas.v2_selected
    redirect_to life_area_selections_path, alert: t("journeys.need_areas") and return if @life_areas.empty?

    @journey = current_user.life_journeys.new(life_area_id: params[:life_area_id])
  end

  def create
    area = current_user.life_areas.v2_selected.find(params.require(:life_journey)[:life_area_id])
    journey = Journeys::Create.call(
      user: current_user,
      life_area: area,
      title: params[:life_journey][:title],
      ideal_scene: params[:life_journey][:ideal_scene],
      current_reality: params[:life_journey][:current_reality],
      closer_percent: params[:life_journey][:closer_percent]
    )
    redirect_to focus_path, notice: t("journeys.created")
  rescue Journeys::Create::Error, ActiveRecord::RecordNotFound => e
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
