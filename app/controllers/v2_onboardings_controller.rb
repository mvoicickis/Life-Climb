# frozen_string_literal: true

class V2OnboardingsController < ApplicationController
  skip_onboarding_check

  # Simplified MVP adventure start — no life-area picker, no long coach funnel.
  STEPS = %w[welcome mountain deadline forge].freeze
  DEFAULT_AREA_KEY = "self".freeze

  def show
    @draft = (session[:v2_onboarding] || {}).stringify_keys
    @step = (params[:step].presence || "welcome").to_s
    @step = "welcome" unless STEPS.include?(@step)

    if current_user.onboarding_completed? && current_user.planning_v2? && @step != "forge"
      redirect_to dashboard_path and return
    end

    redirect_to v2_onboarding_path(step: missing_step) and return if step_incomplete?
  end

  def update
    draft = (session[:v2_onboarding] || {}).stringify_keys.merge(onboarding_params.to_h.stringify_keys)
    session[:v2_onboarding] = draft
    step = params[:step].to_s

    case step
    when "welcome"
      redirect_to v2_onboarding_path(step: "mountain")
    when "mountain"
      title = draft["title"].to_s.strip
      if title.blank?
        redirect_to v2_onboarding_path(step: "mountain"), alert: t("v2_onboarding.need_mountain") and return
      end
      session[:v2_onboarding] = draft.merge("title" => title)
      redirect_to v2_onboarding_path(step: "deadline")
    when "deadline"
      begin
        Onboarding::Run.call(
          user: current_user,
          area_key: DEFAULT_AREA_KEY,
          title: draft["title"],
          route_mission: true
        )
        session.delete(:v2_onboarding)
        redirect_to v2_onboarding_path(step: "forge")
      rescue Onboarding::Run::Error, LifeAreas::Select::Error, Journeys::Create::Error, Focus::SetJourneys::Error => e
        redirect_to v2_onboarding_path(step: "mountain"), alert: e.message
      end
    else
      redirect_to v2_onboarding_path(step: "welcome")
    end
  end

  private

  def onboarding_params
    params.fetch(:onboarding, {}).permit(:title)
  end

  def step_incomplete?
    case @step
    when "welcome", "mountain" then false
    when "deadline" then @draft["title"].blank?
    when "forge" then !current_user.onboarding_completed?
    else false
    end
  end

  def missing_step
    return "forge" if current_user.onboarding_completed?
    return "mountain" if @draft["title"].blank? && @step == "deadline"
    return "welcome" if @draft["title"].blank? && !@step.in?(%w[welcome mountain])

    "mountain"
  end
end