class BuildingsController < ApplicationController
  # show uses singular /building (no :id). Only member actions need set_building.
  before_action :set_building, only: %i[focus ship]

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
      title: ship_params[:title].presence,
      value_summary: ship_params[:value_summary].presence
    ).call

    redirect_to finished_product_path(product), notice: t("buildings.shipped")
  end

  private

  def ship_params
    params.permit(:title, :value_summary)
  end

  def set_building
    @building = current_user.buildings.find(params[:id])
  end

  def load_building_context
    @actions_today = @building.today_actions.for_day(Date.current).ordered
    @dream = @building.dream
    @goal = @building.goal
    @step = @building.step
    @life_area = @goal.life_area
    @all_buildings = current_user.buildings.active.includes(step: { goal: :dream }).order(:id)
    @alive_level = current_user.alive_level
    goal_steps = @goal.steps.ordered.to_a
    @steps_total = goal_steps.size
    @steps_done = goal_steps.count { |s| s.status == "done" }
    @plan_progress = @steps_total.zero? ? 0 : ((@steps_done.to_f / @steps_total) * 100).round
  end
end
