# frozen_string_literal: true

class V2OnboardingsController < ApplicationController
  skip_onboarding_check

  STEPS = %w[goal camps].freeze
  SETUP_STEPS = STEPS.freeze
  LEGACY_STEPS = %w[welcome category mountain commitment deadline forge how].freeze
  RETIRED_STEPS = %w[character camp battles basic].freeze

  def show
    return redirect_completed_user! if current_user.onboarding_completed? && current_user.planning_v2?

    @draft = normalized_draft
    @step = (params[:step].presence || "goal").to_s
    if LEGACY_STEPS.include?(@step) || RETIRED_STEPS.include?(@step)
      redirect_to v2_onboarding_path(step: missing_step) and return
    end
    @step = "goal" unless STEPS.include?(@step)

    if SETUP_STEPS.include?(@step)
      @setup_step_index = SETUP_STEPS.index(@step) + 1
      @setup_step_total = SETUP_STEPS.size
    end

    redirect_to v2_onboarding_path(step: missing_step) and return if step_incomplete?

    track_onboarding_event!("onboarding_step_viewed", @step)
  end

  def update
    return redirect_completed_user! if current_user.onboarding_completed? && current_user.planning_v2?

    draft = normalized_draft.merge(onboarding_params.to_h.stringify_keys)
    session[:v2_onboarding] = draft
    step = params[:step].to_s
    if LEGACY_STEPS.include?(step) || RETIRED_STEPS.include?(step)
      legacy_draft = draft
      if step == "mountain"
        title = params.dig(:onboarding, :title).to_s.strip
        legacy_draft = legacy_draft.merge("goal" => title) if title.present?
        session[:v2_onboarding] = legacy_draft
      end
      redirect_to v2_onboarding_path(step: missing_step) and return
    end
    step = "goal" unless STEPS.include?(step)

    case step
    when "goal"
      goal = draft["goal"].to_s.strip
      if goal.blank?
        redirect_to v2_onboarding_path(step: "goal"), alert: t("v2_onboarding.need_goal") and return
      end
      session[:v2_onboarding] = draft.merge("goal" => goal)
      track_onboarding_event!("onboarding_step_completed", step)
      redirect_to v2_onboarding_path(step: "camps")
    when "camps"
      titles = camp_titles_from_params.presence || camp_titles_from_draft(draft)
      if titles.empty?
        redirect_to v2_onboarding_path(step: "camps"), alert: t("v2_onboarding.need_camp") and return
      end
      if draft["goal"].blank?
        redirect_to v2_onboarding_path(step: "goal"), alert: t("v2_onboarding.need_goal") and return
      end
      session[:v2_onboarding] = draft.merge("camp_titles" => titles)
      track_onboarding_event!("onboarding_step_completed", step)
      begin
        result = Onboarding::Bootstrap.call(
          user: current_user,
          goal_title: draft["goal"],
          camp_titles: titles
        )
        session.delete(:v2_onboarding)
        redirect_to life_journey_path(result.journey, open_camp: result.projects.first.id)
      rescue Onboarding::Bootstrap::Error => e
        redirect_to v2_onboarding_path(step: "camps"), alert: e.message
      end
    else
      redirect_to v2_onboarding_path(step: "goal")
    end
  end

  private

  def onboarding_params
    params.fetch(:onboarding, {}).permit(:goal, :title, camp_titles: [])
  end

  def camp_titles_from_params
    from_onboarding = Array(params.dig(:onboarding, :camp_titles)).map(&:to_s).map(&:strip).reject(&:blank?)
    return from_onboarding if from_onboarding.any?

    Array(params[:camp_titles]).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def camp_titles_from_draft(draft)
    Array(draft["camp_titles"]).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def camp_titles_blank?(draft)
    camp_titles_from_draft(draft).empty?
  end

  def normalized_draft
    draft = (session[:v2_onboarding] || {}).stringify_keys
    return draft if current_user.onboarding_completed?

    draft["goal"] = draft["goal"].presence || draft.delete("title")
    if draft["camp"].present? && camp_titles_blank?(draft)
      draft["camp_titles"] = [ draft["camp"].to_s.strip ].reject(&:blank?)
    end
    draft.delete("camp")
    %w[category area_key commitment_key due_on battle_titles basic_title].each { |key| draft.delete(key) }
    draft
  end

  def redirect_completed_user!
    journey = current_user.primary_focused_journey || current_user.life_journeys.active.order(:id).first
    if journey.present?
      redirect_to life_journey_path(journey)
    else
      redirect_to dashboard_path
    end
  end

  def step_incomplete?
    draft = normalized_draft
    case @step
    when "goal" then false
    when "camps" then draft["goal"].blank?
    else false
    end
  end

  def missing_step
    draft = normalized_draft
    return "goal" if draft["goal"].blank?

    "camps"
  end

  def track_onboarding_event!(name, step)
    return unless SETUP_STEPS.include?(step)

    Analytics::Track.call(user: current_user, name: name, properties: { step: step })
  end
end
