# frozen_string_literal: true

class V2OnboardingsController < ApplicationController
  skip_onboarding_check

  INTRO_STEPS = %w[intro_big_goals intro_battles].freeze
  POST_SETUP_STEPS = %w[climb battles celebrate].freeze
  STEPS = (INTRO_STEPS + %w[goal camps] + POST_SETUP_STEPS).freeze
  SETUP_STEPS = %w[goal camps battles].freeze
  SETUP_STEP_DISPLAY_TOTAL = 3
  LEGACY_STEPS = %w[welcome category mountain commitment deadline forge how].freeze
  RETIRED_STEPS = %w[character camp basic].freeze

  def show
    return redirect_completed_user! if current_user.onboarding_completed? && current_user.planning_v2?

    @draft = normalized_draft
    @step = requested_step
    if LEGACY_STEPS.include?(@step) || RETIRED_STEPS.include?(@step)
      redirect_to v2_onboarding_path(step: legacy_or_retired_redirect_step(@step)) and return
    end
    unless STEPS.include?(@step)
      redirect_to v2_onboarding_path(step: entry_step) and return
    end

    if pending_v3_spine_step?
      resume = resume_post_camps_step
      blocked = INTRO_STEPS + %w[goal camps]
      if blocked.include?(@step) || (POST_SETUP_STEPS.include?(@step) && @step != resume)
        redirect_to v2_onboarding_path(step: resume) and return
      end
    end

    if INTRO_STEPS.include?(@step) && draft_goal_present? && !pending_v3_spine_step?
      redirect_to v2_onboarding_path(step: missing_step) and return
    end

    if %w[goal camps battles].include?(@step)
      @setup_step_index = setup_display_index(@step)
      @setup_step_total = SETUP_STEP_DISPLAY_TOTAL
    end

    journey = onboarding_bootstrap_journey
    if @step == "climb"
      unless journey
        redirect_to v2_onboarding_path(step: entry_step) and return
      end

      @goal_title = journey.title
      @camp_titles = camp_titles_for_journey(journey)
    elsif @step == "battles"
      unless journey
        redirect_to v2_onboarding_path(step: entry_step) and return
      end

      @journey = journey
      @battle_titles = existing_battle_titles_for(journey)
      @first_camp_title = first_camp_project_for(journey)&.title
    elsif @step == "celebrate"
      unless journey && onboarding_first_camp_has_battles?(journey)
        redirect_to v2_onboarding_path(step: resume_post_camps_step) and return
      end
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
        session[:v2_onboarding_from_legacy_mountain] = true
      end
      redirect_to v2_onboarding_path(step: legacy_or_retired_redirect_step(step)) and return
    end
    unless STEPS.include?(step)
      redirect_to v2_onboarding_path(step: entry_step) and return
    end

    case step
    when *INTRO_STEPS
      skipped = intro_skip_requested?
      track_onboarding_event!("onboarding_step_completed", step, skipped: skipped)
      redirect_to intro_after_step(step, skipped: skipped)
    when "goal"
      goal = draft["goal"].to_s.strip
      if goal.blank?
        redirect_to v2_onboarding_path(step: "goal"), alert: t("v2_onboarding.need_goal") and return
      end
      session[:v2_onboarding] = draft.merge("goal" => goal)
      session.delete(:v2_onboarding_from_legacy_mountain)
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
      if current_user.onboarding_completed? && current_user.planning_v2?
        session.delete(:v2_onboarding)
        redirect_completed_user! and return
      end

      if (existing_journey = onboarding_bootstrap_journey)
        session.delete(:v2_onboarding)
        session.delete(:v2_onboarding_from_legacy_mountain)
        if current_user.onboarding_completed?
          redirect_after_onboarding!(fallback: life_journey_path(existing_journey)) and return
        else
          redirect_to v2_onboarding_path(step: resume_post_camps_step) and return
        end
      end

      session[:v2_onboarding] = draft.merge("camp_titles" => titles)
      track_onboarding_event!("onboarding_step_completed", step)
      begin
        Onboarding::Bootstrap.call(
          user: current_user,
          goal_title: draft["goal"],
          camp_titles: titles,
          complete_onboarding: false,
          first_camp_reveal_status: "done"
        )
        session.delete(:v2_onboarding)
        session.delete(:v2_onboarding_from_legacy_mountain)
        redirect_to v2_onboarding_path(step: "climb")
      rescue Onboarding::Bootstrap::Error => e
        redirect_to v2_onboarding_path(step: "camps"), alert: e.message
      end
    when "climb"
      journey = onboarding_bootstrap_journey
      unless journey
        redirect_to v2_onboarding_path(step: entry_step) and return
      end

      journey.mark_onboarding_v3_climb_done!
      track_onboarding_event!("onboarding_step_completed", step)
      session.delete(:v2_onboarding)
      session.delete(:v2_onboarding_from_legacy_mountain)
      redirect_to v2_onboarding_path(step: "battles")
    when "battles"
      journey = onboarding_bootstrap_journey
      unless journey&.onboarding_v3_climb_done?
        redirect_to v2_onboarding_path(step: "climb") and return
      end

      titles = battle_titles_from_params
      if titles.empty? && !onboarding_first_camp_has_battles?(journey)
        redirect_to v2_onboarding_path(step: "battles"), alert: t("v2_onboarding.need_battle") and return
      end

      begin
        Onboarding::PlantBattles.call(user: current_user, journey: journey, battle_titles: titles) if titles.any?
      rescue Onboarding::PlantBattles::Error => e
        redirect_to v2_onboarding_path(step: "battles"), alert: e.message and return
      end

      track_onboarding_event!("onboarding_step_completed", step)
      redirect_to v2_onboarding_path(step: "celebrate")
    when "celebrate"
      journey = onboarding_bootstrap_journey
      unless journey && onboarding_first_camp_has_battles?(journey)
        redirect_to v2_onboarding_path(step: resume_post_camps_step) and return
      end

      complete_v2_onboarding!
      track_onboarding_event!("onboarding_step_completed", step)
      session.delete(:v2_onboarding)
      session.delete(:v2_onboarding_from_legacy_mountain)
      redirect_after_onboarding!(fallback: dashboard_path)
    else
      redirect_to v2_onboarding_path(step: entry_step)
    end
  end

  private

  def requested_step
    step = params[:step].presence&.to_s
    return entry_step if step.blank?

    step
  end

  def entry_step
    return resume_post_camps_step if pending_v3_spine_step?

    draft_goal_present? ? missing_step : "intro_big_goals"
  end

  def pending_v3_spine_step?
    return false if current_user.onboarding_completed?

    onboarding_bootstrap_journey.present?
  end

  def resume_post_camps_step
    journey = onboarding_bootstrap_journey
    return "intro_big_goals" unless journey

    return "celebrate" if onboarding_first_camp_has_battles?(journey)
    return "battles" if journey.onboarding_v3_climb_done?

    "climb"
  end

  def draft_goal_present?
    normalized_draft["goal"].to_s.strip.present?
  end

  def intro_skip_requested?
    ActiveModel::Type::Boolean.new.cast(params[:skip]) ||
      ActiveModel::Type::Boolean.new.cast(params.dig(:onboarding, :skip))
  end

  def intro_after_step(step, skipped:)
    return v2_onboarding_path(step: "goal") if skipped

    case step
    when "intro_big_goals" then v2_onboarding_path(step: "intro_battles")
    when "intro_battles" then v2_onboarding_path(step: "goal")
    else v2_onboarding_path(step: "goal")
    end
  end

  def setup_display_index(step)
    case step
    when "goal" then 1
    when "camps" then 2
    when "battles" then 3
    else 1
    end
  end

  def onboarding_params
    params.fetch(:onboarding, {}).permit(:goal, :title, :skip, camp_titles: [], battle_titles: [])
  end

  def camp_titles_from_params
    from_onboarding = Array(params.dig(:onboarding, :camp_titles)).map(&:to_s).map(&:strip).reject(&:blank?)
    return from_onboarding if from_onboarding.any?

    Array(params[:camp_titles]).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def battle_titles_from_params
    from_onboarding = Array(params.dig(:onboarding, :battle_titles)).map(&:to_s).map(&:strip).reject(&:blank?)
    return from_onboarding if from_onboarding.any?

    Array(params[:battle_titles]).map(&:to_s).map(&:strip).reject(&:blank?)
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
    journey = current_user.primary_focused_journey || current_user.life_journeys.with_destination.order(:id).first
    fallback = journey.present? ? life_journey_path(journey) : dashboard_path
    redirect_after_onboarding!(fallback: fallback)
  end

  def redirect_after_onboarding!(fallback:)
    if (path = climb_invite_resume_path)
      redirect_to path
    else
      redirect_to fallback
    end
  end

  def complete_v2_onboarding!
    return if current_user.onboarding_completed? && current_user.planning_v2?

    current_user.update!(onboarding_completed_at: Time.current, planning_version: 2)
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
    return "intro_big_goals" if draft["goal"].blank?

    return "camps" if session[:v2_onboarding_from_legacy_mountain]

    "goal"
  end

  def legacy_or_retired_redirect_step(legacy_step)
    draft = normalized_draft
    return resume_post_camps_step if pending_v3_spine_step?
    return "intro_big_goals" if draft["goal"].blank?
    return "camps" if legacy_step == "mountain" || session[:v2_onboarding_from_legacy_mountain]
    return "camps" if draft_goal_present?

    "goal"
  end

  def track_onboarding_event!(name, step, **properties)
    return unless STEPS.include?(step)

    Analytics::Track.call(
      user: current_user,
      name: name,
      properties: { step: step }.merge(properties)
    )
  end

  def onboarding_bootstrap_journey
    @onboarding_bootstrap_journey ||= current_user.life_journeys.active.order(id: :desc).find do |journey|
      journey.setup_flag(Onboarding::Bootstrap::BOOTSTRAP_FLAG) == "true"
    end
  end

  def onboarding_first_camp_has_battles?(journey)
    project = first_camp_project_for(journey)
    return false if project.blank?

    project.children.for_kind("day").reject(&:holding?).any?
  end

  def first_camp_project_for(journey)
    camp_id = journey.setup_flag(Onboarding::Bootstrap::FIRST_CAMP_ID_FLAG).to_i
    return if camp_id.blank?

    current_user.strategy_goals
      .where(life_journey_id: journey.id)
      .for_kind("project")
      .not_holding
      .find_by(id: camp_id)
  end

  def existing_battle_titles_for(journey)
    project = first_camp_project_for(journey)
    return [] if project.blank?

    project.children.for_kind("day").order(:position).pluck(:title)
  end

  def camp_titles_for_journey(journey)
    journey.user.strategy_goals
      .where(life_journey_id: journey.id)
      .for_kind("project")
      .order(:position)
      .limit(3)
      .pluck(:title)
  end
end
