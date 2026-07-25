class V2OnboardingsController < ApplicationController
  skip_onboarding_check

  def show
    redirect_to dashboard_path and return if current_user.onboarding_completed? && current_user.planning_v2?

    @step = (params[:step].presence || "area").to_s
    @step = "area" unless %w[area interview].include?(@step)
    @catalog = LifeArea::CATALOG
    @area_key = session.dig(:v2_onboarding, "area_key").to_s
    @area_key = nil unless LifeArea::CATALOG_KEYS.include?(@area_key)

    if @step == "interview" && @area_key.blank?
      redirect_to v2_onboarding_path(step: "area") and return
    end
  end

  def update
    draft = (session[:v2_onboarding] || {}).stringify_keys.merge(onboarding_params.to_h.stringify_keys)
    session[:v2_onboarding] = draft
    step = params[:step].to_s

    case step
    when "area"
      key = draft["area_key"].to_s
      unless LifeArea::CATALOG_KEYS.include?(key)
        redirect_to v2_onboarding_path(step: "area"), alert: t("v2_onboarding.pick_one_area") and return
      end
      session[:v2_onboarding] = draft.slice("area_key")
      redirect_to v2_onboarding_path(step: "interview")
    when "interview"
      key = draft["area_key"].to_s
      begin
        Onboarding::Run.call(
          user: current_user,
          area_key: key,
          title: draft["title"],
          ideal_scene: draft["ideal_scene"],
          current_reality: draft["current_reality"],
          closer_percent: draft["closer_percent"].presence || 30
        )
        session.delete(:v2_onboarding)
        redirect_to dashboard_path, notice: t("v2_onboarding.welcome")
      rescue Onboarding::Run::Error, LifeAreas::Select::Error, Journeys::Create::Error, Focus::SetJourneys::Error => e
        redirect_to v2_onboarding_path(step: "interview"), alert: e.message
      end
    else
      redirect_to v2_onboarding_path(step: "area")
    end
  end

  private

  def onboarding_params
    params.fetch(:onboarding, {}).permit(
      :area_key, :title, :ideal_scene, :current_reality, :closer_percent
    )
  end
end
