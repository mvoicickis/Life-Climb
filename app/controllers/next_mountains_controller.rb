# frozen_string_literal: true

class NextMountainsController < ApplicationController
  COACH_STEPS = %w[want now next today].freeze

  def show
    @completed = current_user.life_journeys.where(status: "completed").order(completed_at: :desc).first
    redirect_to dashboard_path, alert: t("next_mountain.need_complete") and return unless @completed

    @same_area = @completed.life_area
    @catalog = LifeArea::CATALOG
    @draft = (session[:next_mountain] || {}).stringify_keys
    @step = params[:step].presence || "choose"
    @area_key = params[:area_key].presence || @draft["area_key"]
    @area_key = @same_area.key if @area_key.blank? && @step.in?(COACH_STEPS)

    if @step.in?(COACH_STEPS) && !LifeArea::CATALOG_KEYS.include?(@area_key.to_s)
      redirect_to next_mountain_path(step: "pick_area") and return
    end
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
        redirect_to next_mountain_path(step: "want", area_key: completed.life_area.key)
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
      redirect_to next_mountain_path(step: "want", area_key: key)
    when "want"
      if draft["ideal_scene"].to_s.strip.blank?
        redirect_to next_mountain_path(step: "want", area_key: draft["area_key"]), alert: t("coach.need_want") and return
      end
      redirect_to next_mountain_path(step: "now", area_key: draft["area_key"])
    when "now"
      if draft["current_reality"].to_s.strip.blank?
        redirect_to next_mountain_path(step: "now", area_key: draft["area_key"]), alert: t("coach.need_now") and return
      end
      redirect_to next_mountain_path(step: "next", area_key: draft["area_key"])
    when "next"
      if draft["next_win"].to_s.strip.blank?
        redirect_to next_mountain_path(step: "next", area_key: draft["area_key"]), alert: t("coach.need_next") and return
      end
      redirect_to next_mountain_path(step: "today", area_key: draft["area_key"])
    when "today"
      key = draft["area_key"].presence || params[:area_key]
      begin
        Journeys::BeginClimb.call(
          user: current_user,
          area_key: key,
          ideal_scene: draft["ideal_scene"],
          current_reality: draft["current_reality"],
          next_win: draft["next_win"],
          today_mission: draft["today_mission"],
          title: draft["title"].presence || draft["ideal_scene"].to_s.truncate(80),
          closer_percent: draft["closer_percent"].presence || 30
        )
        session.delete(:next_mountain)
        redirect_to dashboard_path, notice: t("next_mountain.started")
      rescue Journeys::BeginClimb::Error, Journeys::Create::Error, Focus::SetJourneys::Error, LifeAreas::Select::Error => e
        redirect_to next_mountain_path(step: "today", area_key: key), alert: e.message
      end
    else
      redirect_to next_mountain_path
    end
  end

  private

  def climb_params
    params.fetch(:climb, {}).permit(
      :area_key, :title, :ideal_scene, :current_reality, :next_win, :today_mission, :closer_percent
    )
  end
end
