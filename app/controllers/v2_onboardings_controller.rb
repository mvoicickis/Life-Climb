# frozen_string_literal: true

class V2OnboardingsController < ApplicationController
  skip_onboarding_check

  # Simplified MVP adventure start — no life-area picker, no long coach funnel.
  STEPS = %w[welcome mountain deadline forge how].freeze
  DEFAULT_AREA_KEY = "self".freeze

  def show
    @draft = (session[:v2_onboarding] || {}).stringify_keys
    @step = (params[:step].presence || "welcome").to_s
    @step = "welcome" unless STEPS.include?(@step)
    @adventure_year = Strategy::YearCycle.target_dec29.year

    if current_user.onboarding_completed? && current_user.planning_v2?
      if current_user.needs_adventure_guide?
        redirect_to v2_onboarding_path(step: "how") and return unless @step.in?(%w[forge how])
      elsif !@step.in?(%w[forge how])
        redirect_to dashboard_path and return
      elsif @step == "how"
        redirect_to dashboard_path and return
      end
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
        # Replaying New Player Experience must not duplicate Goals/Journeys.
        if current_user.life_journeys.exists?
          current_user.update!(onboarding_completed_at: Time.current, planning_version: 2)
        else
          Onboarding::Run.call(
            user: current_user,
            area_key: DEFAULT_AREA_KEY,
            title: draft["title"],
            route_mission: true
          )
        end
        session.delete(:v2_onboarding)
        redirect_to v2_onboarding_path(step: "forge")
      rescue Onboarding::Run::Error, LifeAreas::Select::Error, Journeys::Create::Error, Focus::SetJourneys::Error => e
        redirect_to v2_onboarding_path(step: "mountain"), alert: e.message
      end
    when "how"
      unless current_user.onboarding_completed?
        redirect_to v2_onboarding_path(step: "welcome") and return
      end
      current_user.mark_adventure_guide_done!
      redirect_to dashboard_path
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
    when "how" then !current_user.onboarding_completed?
    else false
    end
  end

  def missing_step
    if current_user.onboarding_completed?
      return "how" if current_user.needs_adventure_guide?
      return "forge"
    end
    return "mountain" if @draft["title"].blank? && @step == "deadline"
    return "welcome" if @draft["title"].blank? && !@step.in?(%w[welcome mountain])

    "mountain"
  end
end
