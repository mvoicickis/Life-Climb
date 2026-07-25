class BuildingsController < ApplicationController
  before_action :set_building, only: %i[show focus ship]

  def show
    @building = current_user.focus_building || current_user.buildings.active.order(:id).first
    if @building.nil?
      redirect_to onboarding_path and return if current_user.needs_onboarding?
      redirect_to life_points_path, alert: t("buildings.empty") and return
    end

    load_building_context
  end

  def focus
    current_user.update!(focus_building: @building)
    redirect_to dashboard_path, notice: t("buildings.focus_set", title: @building.title)
  end

  def ship
    product = ShipBuilding.new(
      building: @building,
      title: params[:title].presence,
      value_summary: params[:value_summary].presence
    ).call

    redirect_to finished_product_path(product), notice: t("buildings.shipped")
  end

  private

  def set_building
    @building = current_user.buildings.find(params[:id])
  end

  def load_building_context
    @actions_today = @building.today_actions.for_day(Date.current).ordered
    @dream = @building.dream
    @goal = @building.goal
    @step = @building.step
    @all_buildings = current_user.buildings.active.includes(step: { goal: :dream }).order(:id)
  end
end
