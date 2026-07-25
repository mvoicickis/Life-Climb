class LifeAreaSelectionsController < ApplicationController
  def show
    @catalog = LifeArea::CATALOG
    @selected_keys = current_user.life_areas.v2_selected.pluck(:key)
  end

  def update
    keys = Array(params[:keys]).map(&:to_s)
    LifeAreas::Select.call(user: current_user, keys: keys)
    redirect_to life_area_selections_path, notice: t("life_area_selections.saved")
  rescue LifeAreas::Select::Error => e
    redirect_to life_area_selections_path, alert: e.message
  end
end
