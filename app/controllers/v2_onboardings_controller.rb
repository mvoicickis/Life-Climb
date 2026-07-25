class V2OnboardingsController < ApplicationController
  skip_onboarding_check

  def show
    redirect_to dashboard_path and return if current_user.onboarding_completed? && current_user.planning_v2?

    @step = (params[:step].presence || "areas").to_s
    @catalog = LifeArea::CATALOG
    @selected = Array(session.dig(:v2_onboarding, "area_keys"))
  end

  def update
    draft = (session[:v2_onboarding] || {}).merge(onboarding_params.to_h)
    session[:v2_onboarding] = draft
    step = params[:step].to_s

    case step
    when "areas"
      keys = Array(draft["area_keys"]).map(&:to_s)
      keys = keys.first(3) if keys.size > 3 && draft["soft_limit"] != "false"
      if keys.empty?
        redirect_to v2_onboarding_path(step: "areas"), alert: t("v2_onboarding.pick_areas") and return
      end
      # Soft default: keep first 3 if they picked a huge set — still allow all if they insist later via settings.
      draft["area_keys"] = keys.size > 6 ? keys.first(3) : keys
      session[:v2_onboarding] = draft
      redirect_to v2_onboarding_path(step: "journey")
    when "journey"
      begin
        Onboarding::Run.call(
          user: current_user,
          area_keys: Array(draft["area_keys"]),
          title: draft["title"],
          ideal_scene: draft["ideal_scene"],
          current_reality: draft["current_reality"],
          closer_percent: draft["closer_percent"].presence || 30
        )
        session.delete(:v2_onboarding)
        redirect_to dashboard_path, notice: t("v2_onboarding.welcome")
      rescue LifeAreas::Select::Error, Journeys::Create::Error, Focus::SetJourneys::Error => e
        redirect_to v2_onboarding_path(step: "journey"), alert: e.message
      end
    else
      redirect_to v2_onboarding_path(step: "areas")
    end
  end

  private

  def onboarding_params
    params.fetch(:onboarding, {}).permit(:title, :ideal_scene, :current_reality, :closer_percent, area_keys: [])
  end
end
