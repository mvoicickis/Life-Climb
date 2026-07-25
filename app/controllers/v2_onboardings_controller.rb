# frozen_string_literal: true

class V2OnboardingsController < ApplicationController
  skip_onboarding_check

  COACH_STEPS = %w[area journey vision reality progress milestone mission].freeze

  def show
    redirect_to dashboard_path and return if current_user.onboarding_completed? && current_user.planning_v2?

    @draft = (session[:v2_onboarding] || {}).stringify_keys
    @step = (params[:step].presence || "area").to_s
    @step = "area" unless COACH_STEPS.include?(@step)
    @catalog = LifeArea::CATALOG
    @area_key = @draft["area_key"].to_s
    @area_key = nil unless LifeArea::CATALOG_KEYS.include?(@area_key)

    if @step != "area" && @area_key.blank?
      redirect_to v2_onboarding_path(step: "area") and return
    end

    redirect_to v2_onboarding_path(step: missing_coach_step) and return if coach_step_incomplete?
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
      redirect_to v2_onboarding_path(step: "journey")
    when "journey"
      if draft["title"].to_s.strip.blank?
        redirect_to v2_onboarding_path(step: "journey"), alert: t("coach.need_journey") and return
      end
      redirect_to v2_onboarding_path(step: "vision")
    when "vision"
      if draft["ideal_scene"].to_s.strip.blank?
        redirect_to v2_onboarding_path(step: "vision"), alert: t("coach.need_vision") and return
      end
      redirect_to v2_onboarding_path(step: "reality")
    when "reality"
      if draft["current_reality"].to_s.strip.blank?
        redirect_to v2_onboarding_path(step: "reality"), alert: t("coach.need_reality") and return
      end
      redirect_to v2_onboarding_path(step: "progress")
    when "progress"
      closer = draft["closer_percent"].presence || "5"
      session[:v2_onboarding] = draft.merge("closer_percent" => closer.to_f.clamp(0, 100).round.to_s)
      redirect_to v2_onboarding_path(step: "milestone")
    when "milestone"
      # Optional — blank or skip both continue
      if params[:skip].present?
        draft = draft.merge("next_win" => "")
        session[:v2_onboarding] = draft
      end
      redirect_to v2_onboarding_path(step: "mission")
    when "mission"
      begin
        Onboarding::Run.call(
          user: current_user,
          area_key: draft["area_key"],
          title: draft["title"],
          ideal_scene: draft["ideal_scene"],
          current_reality: draft["current_reality"],
          next_win: draft["next_win"].presence,
          today_mission: draft["today_mission"],
          closer_percent: draft["closer_percent"].presence || 5
        )
        session.delete(:v2_onboarding)
        redirect_to dashboard_path, notice: t("v2_onboarding.welcome")
      rescue Onboarding::Run::Error, LifeAreas::Select::Error, Journeys::Create::Error, Focus::SetJourneys::Error => e
        redirect_to v2_onboarding_path(step: "mission"), alert: e.message
      end
    else
      redirect_to v2_onboarding_path(step: "area")
    end
  end

  private

  def onboarding_params
    params.fetch(:onboarding, {}).permit(
      :area_key, :title, :ideal_scene, :current_reality, :next_win, :today_mission, :closer_percent
    )
  end

  def coach_step_incomplete?
    return false if @step == "area"

    case @step
    when "vision" then @draft["title"].blank?
    when "reality" then @draft["title"].blank? || @draft["ideal_scene"].blank?
    when "progress"
      @draft["title"].blank? || @draft["ideal_scene"].blank? || @draft["current_reality"].blank?
    when "milestone", "mission"
      @draft["title"].blank? || @draft["ideal_scene"].blank? ||
        @draft["current_reality"].blank? || @draft["closer_percent"].blank?
    else
      false
    end
  end

  def missing_coach_step
    return "journey" if @draft["title"].blank?
    return "vision" if @draft["ideal_scene"].blank?
    return "reality" if @draft["current_reality"].blank?
    return "progress" if @draft["closer_percent"].blank?

    @step.in?(%w[milestone mission]) ? @step : "milestone"
  end
end
