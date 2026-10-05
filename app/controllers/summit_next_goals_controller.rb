# frozen_string_literal: true

class SummitNextGoalsController < ApplicationController
  before_action :require_planning_v2
  before_action :set_summit_journey

  STEPS = %w[goal camps].freeze

  def show
    return redirect_to life_journey_path(@journey) unless summit_eligible?(@journey)

    @draft = normalized_draft(@journey)
    @step = (params[:step].presence || "goal").to_s
    @step = "goal" unless STEPS.include?(@step)
    @setup_step_index = STEPS.index(@step) + 1
    @setup_step_total = STEPS.size

    redirect_to summit_next_goal_path(step: "goal") and return if @step == "camps" && @draft["goal"].blank?
  end

  def update
    step = params[:step].to_s
    step = "goal" unless STEPS.include?(step)

    draft = normalized_draft(@journey).merge(onboarding_params.to_h.stringify_keys)
    draft["life_journey_id"] = @journey.id
    session[:summit_next_goal] = draft

    case step
    when "goal"
      goal = draft["goal"].to_s.strip
      if goal.blank?
        redirect_to summit_next_goal_path(step: "goal"), alert: t("v2_onboarding.need_goal") and return
      end
      session[:summit_next_goal] = draft.merge("goal" => goal, "life_journey_id" => @journey.id)
      redirect_to summit_next_goal_path(step: "camps")
    when "camps"
      unless summit_eligible?(@journey)
        return handle_already_completed_redirect
      end

      titles = camp_titles_from_params.presence || camp_titles_from_draft(draft)
      if titles.empty?
        respond_to_invalid_camps and return
      end
      if draft["goal"].blank?
        redirect_to summit_next_goal_path(step: "goal"), alert: t("v2_onboarding.need_goal") and return
      end

      session[:summit_next_goal] = draft.merge("camp_titles" => titles, "life_journey_id" => @journey.id)

      begin
        result = Journeys::StartNextGoal.call(
          user: current_user,
          old_journey: @journey,
          goal_title: draft["goal"],
          camp_titles: titles
        )
        session.delete(:summit_next_goal)
        respond_to_success(result.journey)
      rescue Journeys::StartNextGoal::AlreadyCompleted
        handle_already_completed_redirect
      rescue Journeys::StartNextGoal::Error => e
        Rails.logger.warn("[SummitNextGoalsController#update] #{e.class}: #{e.message}")
        respond_to_failure
      end
    else
      redirect_to summit_next_goal_path(step: "goal")
    end
  end

  private

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to dashboard_path, alert: t("strategy.need_v2"), status: :see_other
  end

  def set_summit_journey
    journey = Goals::Current.journey_for(user: current_user)
    if journey.blank?
      redirect_to dashboard_path, alert: t("journeys.missing_redirect"), status: :see_other
      return
    end

    @journey = current_user.life_journeys.find(journey.id)
  end

  def summit_eligible?(journey)
    journey.status == "active" && Strategy::SummitReached.on_journey?(user: current_user, journey: journey)
  end

  def normalized_draft(journey)
    draft = (session[:summit_next_goal] || {}).stringify_keys
    if draft["life_journey_id"].present? && draft["life_journey_id"].to_i != journey.id
      session.delete(:summit_next_goal)
      draft = {}
    end
    draft
  end

  def onboarding_params
    params.fetch(:onboarding, {}).permit(:goal, camp_titles: [])
  end

  def camp_titles_from_params
    from_onboarding = Array(params.dig(:onboarding, :camp_titles)).map(&:to_s).map(&:strip).reject(&:blank?)
    return from_onboarding if from_onboarding.any?

    Array(params[:camp_titles]).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def camp_titles_from_draft(draft)
    Array(draft["camp_titles"]).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def handle_already_completed_redirect
    journey = Goals::Current.journey_for(user: current_user)
    path = journey.present? ? life_journey_path(journey) : dashboard_path
    respond_to do |format|
      format.html { redirect_to path, status: :see_other }
      format.json { render json: { redirect_to: path } }
    end
  end

  def respond_to_success(journey)
    path = life_journey_path(journey)
    respond_to do |format|
      format.html { redirect_to path, status: :see_other }
      format.json { render json: { redirect_to: path } }
    end
  end

  def respond_to_failure
    respond_to do |format|
      format.html do
        redirect_to summit_next_goal_path(step: "camps"), alert: t("dash.battlefield.win_not_saved")
      end
      format.json { render json: { error: t("dash.battlefield.win_not_saved") }, status: :unprocessable_entity }
    end
  end

  def respond_to_invalid_camps
    respond_to do |format|
      format.html do
        redirect_to summit_next_goal_path(step: "camps"), alert: t("v2_onboarding.need_camp")
      end
      format.json { render json: { error: t("v2_onboarding.need_camp") }, status: :unprocessable_entity }
    end
  end
end
