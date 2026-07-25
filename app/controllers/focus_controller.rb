class FocusController < ApplicationController
  before_action :require_planning_v2

  def show
    @journeys = current_user.life_journeys.active.order(:id)
    redirect_to new_life_journey_path, alert: t("focus.need_journey") and return if @journeys.empty?

    @selected_ids = current_user.focused_journeys.pluck(:id)
  end

  def update
    Focus::SetJourneys.call(user: current_user, journey_ids: params[:journey_ids])
    Missions::EnsureDaily.call(user: current_user)
    redirect_to dashboard_path, notice: t("focus.saved")
  rescue Focus::SetJourneys::Error => e
    redirect_to focus_path, alert: e.message
  end

  private

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path
  end
end
