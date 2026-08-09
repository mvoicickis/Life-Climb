# frozen_string_literal: true

class V2OnboardingsController < ApplicationController
  skip_onboarding_check

  # Simplified MVP adventure start — category picker, then mountain goal.
  STEPS = %w[welcome character category mountain commitment deadline forge how].freeze
  # User-facing setup progress (forge/how are post-create transitions).
  SETUP_STEPS = %w[welcome character category mountain commitment deadline].freeze
  DEFAULT_AREA_KEY = "self".freeze

  def show
    @draft = (session[:v2_onboarding] || {}).stringify_keys
    @step = (params[:step].presence || "welcome").to_s
    @step = "welcome" unless STEPS.include?(@step)
    @default_due_on = Strategy::YearCycle.default_goal_due
    @goal_due_on = parse_due_on(@draft["due_on"]) || @default_due_on
    @adventure_year = @goal_due_on.year
    @categories = Onboarding::Categories.all
    @onboarding_category = @draft["category"].presence || "self"
    if SETUP_STEPS.include?(@step)
      @setup_step_index = SETUP_STEPS.index(@step) + 1
      @setup_step_total = SETUP_STEPS.size
    end

    if current_user.onboarding_completed? && current_user.planning_v2?
      # Optional how-guide stays reachable; otherwise leave onboarding shell.
      unless @step.in?(%w[forge how])
        redirect_to after_adventure_path and return
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
      redirect_to v2_onboarding_path(step: "character")
    when "character"
      key = params.dig(:user, :character).to_s
      unless User::CHARACTERS.include?(key)
        redirect_to v2_onboarding_path(step: "character"), alert: t("v2_onboarding.need_character") and return
      end
      current_user.update!(character: key)
      current_user.mark_companion_pick_done!
      redirect_to v2_onboarding_path(step: "category")
    when "category"
      category = draft["category"].to_s
      entry = Onboarding::Categories.find(category)
      unless entry
        redirect_to v2_onboarding_path(step: "category"), alert: t("v2_onboarding.need_category") and return
      end
      session[:v2_onboarding] = draft.merge(
        "category" => entry.id,
        "area_key" => entry.area_key
      )
      redirect_to v2_onboarding_path(step: "mountain")
    when "mountain"
      title = draft["title"].to_s.strip
      if title.blank?
        redirect_to v2_onboarding_path(step: "mountain"), alert: t("v2_onboarding.need_mountain") and return
      end
      session[:v2_onboarding] = draft.merge("title" => title)
      redirect_to v2_onboarding_path(step: "commitment")
    when "commitment"
      key = if ActiveModel::Type::Boolean.new.cast(params[:skip])
        "easy"
      else
        draft["commitment_key"].to_s.presence || "easy"
      end
      key = "easy" unless Today::Commitment::PRESETS.key?(key)
      session[:v2_onboarding] = draft.merge("commitment_key" => key)
      redirect_to v2_onboarding_path(step: "deadline")
    when "deadline"
      begin
        area_key = draft["area_key"].presence || Onboarding::Categories.area_key_for(draft["category"]) || DEFAULT_AREA_KEY
        due_on = parse_due_on(draft["due_on"]) || Strategy::YearCycle.default_goal_due
        commitment_key = draft["commitment_key"].presence || "easy"
        Onboarding::Run.call(
          user: current_user,
          area_key: area_key,
          title: draft["title"],
          onboarding_category: draft["category"],
          due_on: due_on,
          commitment_key: commitment_key,
          route_mission: true
        )
        session.delete(:v2_onboarding)
        # Guide is optional — unlock Trail Guide and send players to first climb.
        current_user.mark_adventure_guide_done!
        redirect_to v2_onboarding_path(step: "forge")
      rescue Onboarding::Run::Error, LifeAreas::Select::Error, Journeys::Create::Error, Focus::SetJourneys::Error => e
        redirect_to v2_onboarding_path(step: "mountain"), alert: e.message
      end
    when "how"
      unless current_user.onboarding_completed?
        redirect_to v2_onboarding_path(step: "welcome") and return
      end
      current_user.mark_adventure_guide_done!
      redirect_to after_adventure_path
    when "forge"
      unless current_user.onboarding_completed?
        redirect_to v2_onboarding_path(step: "welcome") and return
      end
      current_user.mark_adventure_guide_done!
      redirect_to after_adventure_path
    else
      redirect_to v2_onboarding_path(step: "welcome")
    end
  end

  private

  def onboarding_params
    params.fetch(:onboarding, {}).permit(:title, :category, :area_key, :due_on, :commitment_key)
  end

  def parse_due_on(raw)
    return if raw.blank?

    date = Date.parse(raw.to_s)
    return if date < Date.current.tomorrow

    date
  rescue ArgumentError, TypeError
    nil
  end

  def after_adventure_path
    journey = current_user.primary_focused_journey || current_user.life_journeys.active.order(:id).first
    return new_life_journey_path if journey.blank?
    return life_journey_path(journey) unless Strategy::HierarchyReady.call(user: current_user, journey:)

    dashboard_path
  end

  def category_missing?
    !Onboarding::Categories.valid_id?(@draft["category"])
  end

  def step_incomplete?
    case @step
    when "welcome", "character" then false
    when "category" then !current_user.character_chosen?
    when "mountain" then !current_user.character_chosen? || category_missing?
    when "commitment" then @draft["title"].blank? || !current_user.character_chosen? || category_missing?
    when "deadline" then @draft["title"].blank? || !current_user.character_chosen? || category_missing?
    when "forge" then !current_user.onboarding_completed?
    when "how" then !current_user.onboarding_completed?
    else false
    end
  end

  def missing_step
    if current_user.onboarding_completed?
      return "forge"
    end
    return "character" if !current_user.character_chosen? && @step.in?(%w[category mountain commitment deadline])
    return "category" if category_missing? && @step.in?(%w[mountain commitment deadline])
    return "mountain" if @draft["title"].blank? && @step.in?(%w[commitment deadline])
    return "welcome" if @draft["title"].blank? && !@step.in?(%w[welcome character category mountain])

    "mountain"
  end
end
