# frozen_string_literal: true

class V2OnboardingsController < ApplicationController
  skip_onboarding_check

  STEPS = %w[character goal camp battles].freeze
  SETUP_STEPS = STEPS.freeze
  LEGACY_STEPS = %w[welcome category mountain commitment deadline forge how].freeze

  def show
    return redirect_completed_user! if current_user.onboarding_completed? && current_user.planning_v2?

    @draft = normalized_draft
    @step = (params[:step].presence || "character").to_s
    if LEGACY_STEPS.include?(@step)
      redirect_to v2_onboarding_path(step: missing_step) and return
    end
    @step = "character" unless STEPS.include?(@step)

    if SETUP_STEPS.include?(@step)
      @setup_step_index = SETUP_STEPS.index(@step) + 1
      @setup_step_total = SETUP_STEPS.size
    end

    redirect_to v2_onboarding_path(step: missing_step) and return if step_incomplete?
  end

  def update
    return redirect_completed_user! if current_user.onboarding_completed? && current_user.planning_v2?

    draft = normalized_draft.merge(onboarding_params.to_h.stringify_keys)
    session[:v2_onboarding] = draft
    step = params[:step].to_s
    if LEGACY_STEPS.include?(step)
      legacy_draft = draft
      if step == "mountain"
        title = params.dig(:onboarding, :title).to_s.strip
        legacy_draft = legacy_draft.merge("goal" => title) if title.present?
        session[:v2_onboarding] = legacy_draft
      end
      redirect_to v2_onboarding_path(step: missing_step) and return
    end
    step = "character" unless STEPS.include?(step)

    case step
    when "character"
      key = params.dig(:user, :character).to_s
      unless User::CHARACTERS.include?(key)
        redirect_to v2_onboarding_path(step: "character"), alert: t("v2_onboarding.need_character") and return
      end
      current_user.update!(character: key)
      current_user.mark_companion_pick_done!
      redirect_to v2_onboarding_path(step: "goal")
    when "goal"
      goal = draft["goal"].to_s.strip
      if goal.blank?
        redirect_to v2_onboarding_path(step: "goal"), alert: t("v2_onboarding.need_goal") and return
      end
      session[:v2_onboarding] = draft.merge("goal" => goal)
      redirect_to v2_onboarding_path(step: "camp")
    when "camp"
      camp = draft["camp"].to_s.strip
      if camp.blank?
        redirect_to v2_onboarding_path(step: "camp"), alert: t("v2_onboarding.need_camp") and return
      end
      session[:v2_onboarding] = draft.merge("camp" => camp)
      redirect_to v2_onboarding_path(step: "battles")
    when "battles"
      titles = battle_titles_from_params
      if titles.empty?
        redirect_to v2_onboarding_path(step: "battles"), alert: t("v2_onboarding.need_battle") and return
      end
      begin
        result = Onboarding::Bootstrap.call(
          user: current_user,
          goal_title: draft["goal"],
          camp_title: draft["camp"],
          battle_titles: titles
        )
        session.delete(:v2_onboarding)
        redirect_to life_journey_path(result.journey)
      rescue Onboarding::Bootstrap::Error => e
        redirect_to v2_onboarding_path(step: "battles"), alert: e.message
      end
    else
      redirect_to v2_onboarding_path(step: "character")
    end
  end

  private

  def onboarding_params
    params.fetch(:onboarding, {}).permit(:goal, :camp, :title, battle_titles: [])
  end

  def battle_titles_from_params
    from_onboarding = Array(params.dig(:onboarding, :battle_titles)).map(&:to_s).map(&:strip).reject(&:blank?)
    return from_onboarding if from_onboarding.any?

    Array(params[:battle_titles]).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def normalized_draft
    draft = (session[:v2_onboarding] || {}).stringify_keys
    return draft if current_user.onboarding_completed?

    draft["goal"] = draft["goal"].presence || draft.delete("title")
    %w[category area_key commitment_key due_on].each { |key| draft.delete(key) }
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
    when "character" then false
    when "goal" then !current_user.character_chosen?
    when "camp" then !current_user.character_chosen? || draft["goal"].blank?
    when "battles" then !current_user.character_chosen? || draft["goal"].blank? || draft["camp"].blank?
    else false
    end
  end

  def missing_step
    draft = normalized_draft
    return "character" unless current_user.character_chosen?
    return "goal" if draft["goal"].blank?
    return "camp" if draft["camp"].blank?

    "battles"
  end
end
