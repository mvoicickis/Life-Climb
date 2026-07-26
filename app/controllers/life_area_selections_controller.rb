class LifeAreaSelectionsController < ApplicationController
  def show
    @catalog = LifeArea::CATALOG
    @selected_keys = current_user.life_areas.v2_selected.pluck(:key)
  end

  def update
    raw_keys =
      if params.key?(:key)
        [ params[:key] ]
      else
        Array(params[:keys])
      end
    LifeAreas::Select.call(user: current_user, keys: raw_keys)
    redirect_after_select
  rescue LifeAreas::Select::Error => e
    redirect_to life_area_selections_path, alert: e.message
  end

  private

  def redirect_after_select
    journey = current_user.reload.primary_focused_journey
    if journey
      redirect_to dashboard_path, notice: t("life_area_selections.saved")
    elsif (active = current_user.life_journeys.active.joins(:life_area).merge(LifeArea.v2_selected).order(:id).first)
      Focus::SetJourneys.call(user: current_user, journey_ids: [ active.id ])
      redirect_to dashboard_path, notice: t("life_area_selections.saved")
    else
      redirect_to new_life_journey_path, notice: t("life_area_selections.saved_start_journey")
    end
  rescue Focus::SetJourneys::Error
    redirect_to new_life_journey_path, notice: t("life_area_selections.saved_start_journey")
  end
end
