class NextMountainsController < ApplicationController
  def show
    @completed = current_user.life_journeys.where(status: "completed").order(completed_at: :desc).first
    redirect_to dashboard_path, alert: t("next_mountain.need_complete") and return unless @completed

    @same_area = @completed.life_area
    @catalog = LifeArea::CATALOG
    @step = params[:step].presence || "choose"
    @area_key = params[:area_key].presence || session.dig(:next_mountain, "area_key")
  end

  def update
    step = params[:step].to_s
    draft = (session[:next_mountain] || {}).stringify_keys.merge(climb_params.to_h.stringify_keys)
    session[:next_mountain] = draft

    case step
    when "choose"
      choice = params[:choice].to_s
      completed = current_user.life_journeys.where(status: "completed").order(completed_at: :desc).first
      redirect_to next_mountain_path, alert: t("next_mountain.need_complete") and return unless completed

      if choice == "same"
        session[:next_mountain] = { "area_key" => completed.life_area.key }
        redirect_to next_mountain_path(step: "interview", area_key: completed.life_area.key)
      elsif choice == "other"
        redirect_to next_mountain_path(step: "pick_area")
      else
        redirect_to next_mountain_path, alert: t("next_mountain.pick_choice")
      end
    when "pick_area"
      key = draft["area_key"].to_s
      unless LifeArea::CATALOG_KEYS.include?(key)
        redirect_to next_mountain_path(step: "pick_area"), alert: t("v2_onboarding.pick_one_area") and return
      end
      redirect_to next_mountain_path(step: "interview", area_key: key)
    when "interview"
      key = draft["area_key"].presence || params[:area_key]
      begin
        Journeys::BeginClimb.call(
          user: current_user,
          area_key: key,
          title: draft["title"],
          ideal_scene: draft["ideal_scene"],
          current_reality: draft["current_reality"],
          closer_percent: draft["closer_percent"].presence || 30
        )
        session.delete(:next_mountain)
        redirect_to dashboard_path, notice: t("next_mountain.started")
      rescue Journeys::BeginClimb::Error, Journeys::Create::Error, Focus::SetJourneys::Error, LifeAreas::Select::Error => e
        redirect_to next_mountain_path(step: "interview", area_key: key), alert: e.message
      end
    else
      redirect_to next_mountain_path
    end
  end

  private

  def climb_params
    params.fetch(:climb, {}).permit(:area_key, :title, :ideal_scene, :current_reality, :closer_percent)
  end
end
