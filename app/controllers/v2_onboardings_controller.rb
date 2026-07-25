# frozen_string_literal: true

class V2OnboardingsController < ApplicationController
  skip_onboarding_check

  COACH_STEPS = %w[area want now next today].freeze

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
      redirect_to v2_onboarding_path(step: "want")
    when "want"
      if draft["ideal_scene"].to_s.strip.blank?
        redirect_to v2_onboarding_path(step: "want"), alert: t("coach.need_want") and return
      end
      redirect_to v2_onboarding_path(step: "now")
    when "now"
      if draft["current_reality"].to_s.strip.blank?
        redirect_to v2_onboarding_path(step: "now"), alert: t("coach.need_now") and return
      end
      redirect_to v2_onboarding_path(step: "next")
    when "next"
      if draft["next_win"].to_s.strip.blank?
        redirect_to v2_onboarding_path(step: "next"), alert: t("coach.need_next") and return
      end
      redirect_to v2_onboarding_path(step: "today")
    when "today"
      begin
        Onboarding::Run.call(
          user: current_user,
          area_key: draft["area_key"],
          ideal_scene: draft["ideal_scene"],
          current_reality: draft["current_reality"],
          next_win: draft["next_win"],
          today_mission: draft["today_mission"],
          title: draft["title"].presence || draft["ideal_scene"].to_s.truncate(80),
          closer_percent: draft["closer_percent"].presence || 30
        )
        session.delete(:v2_onboarding)
        redirect_to dashboard_path, notice: t("v2_onboarding.welcome")
      rescue Onboarding::Run::Error, LifeAreas::Select::Error, Journeys::Create::Error, Focus::SetJourneys::Error => e
        redirect_to v2_onboarding_path(step: "today"), alert: e.message
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
    when "now" then @draft["ideal_scene"].blank?
    when "next" then @draft["ideal_scene"].blank? || @draft["current_reality"].blank?
    when "today"
      @draft["ideal_scene"].blank? || @draft["current_reality"].blank? || @draft["next_win"].blank?
    else
      false
    end
  end

  def missing_coach_step
    return "want" if @draft["ideal_scene"].blank?
    return "now" if @draft["current_reality"].blank?
    return "next" if @draft["next_win"].blank?

    "today"
  end
end
