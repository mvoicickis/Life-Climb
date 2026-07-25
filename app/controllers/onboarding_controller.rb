class OnboardingController < ApplicationController
  skip_onboarding_check

  PART_STEPS = LifeArea::KEYS.map { |key| "part_#{key}" }.freeze
  FLOW = (
    %w[intro] + PART_STEPS + %w[focus goal steps building today]
  ).freeze

  def show
    redirect_to dashboard_path and return if current_user.onboarding_completed? && current_user.dreams.any?

    @step = (params[:step].presence || session[:onboarding_step] || "intro").to_s
    @step = "intro" unless FLOW.include?(@step)
    session[:onboarding_step] = @step
    @draft = session[:onboarding_draft] || {}
    @part_key = part_key_from_step(@step)
  end

  def update
    @step = params[:step].to_s
    @draft = (session[:onboarding_draft] || {}).deep_merge(draft_params.to_h)
    @part_key = part_key_from_step(@step)

    case @step
    when "intro"
      title = @draft["dream"].to_s.strip
      title = I18n.t("onboarding.default_dream_title") if title.blank?
      @draft["dream"] = title
      advance!(@draft, next_step_after("intro"))
    when *PART_STEPS
      handle_part_step!
    when "focus"
      key = @draft["focus_key"].to_s
      return fail_step("focus") unless LifeArea::KEYS.include?(key) && part_filled?(key)
      advance!(@draft, "goal")
    when "goal"
      return fail_step("goal") if @draft["goal"].to_s.strip.blank?
      advance!(@draft, "steps")
    when "steps"
      steps = Array(@draft["steps"]).map { |s| s.to_s.strip }.reject(&:blank?)
      steps = default_steps if steps.empty?
      @draft["steps"] = steps
      advance!(@draft, "building")
    when "building"
      return fail_step("building") if @draft["building"].to_s.strip.blank?
      advance!(@draft, "today")
    when "today"
      actions = Array(@draft["actions"]).map { |s| s.to_s.strip }.reject(&:blank?)
      return fail_step("today") if actions.empty?
      @draft["actions"] = actions
      finalize!(@draft)
      redirect_to dashboard_path, notice: t("onboarding.welcome")
    else
      redirect_to onboarding_path(step: "intro")
    end
  end

  private

  def draft_params
    params.fetch(:onboarding, {}).permit(
      :dream, :goal, :building, :focus_key, :skip,
      :ambition, :present_scene, :has_partner,
      steps: [], actions: []
    )
  end

  def handle_part_step!
    key = @part_key
    parts = (@draft["parts"] || {}).stringify_keys
    skipped = ActiveModel::Type::Boolean.new.cast(@draft["skip"])

    if key == "physical_world" && skipped
      parts[key] = { "ambition" => "", "present_scene" => "", "meta" => {} }
    else
      ambition = @draft["ambition"].to_s.strip
      present = @draft["present_scene"].to_s.strip
      if ambition.blank?
        if key == "physical_world"
          parts[key] = { "ambition" => "", "present_scene" => "", "meta" => {} }
        else
          return fail_step(@step) unless optional_part?(key)
          parts[key] = { "ambition" => "", "present_scene" => "", "meta" => {} }
        end
      else
        meta = {}
        if key == "love" && !@draft["has_partner"].nil?
          meta["has_partner"] = ActiveModel::Type::Boolean.new.cast(@draft["has_partner"])
        end
        parts[key] = { "ambition" => ambition, "present_scene" => present, "meta" => meta }
      end
    end

    @draft["parts"] = parts
    @draft.delete("ambition")
    @draft.delete("present_scene")
    @draft.delete("has_partner")
    @draft.delete("skip")

    if key == "physical_world" && !enough_parts_filled?(parts)
      session[:onboarding_draft] = @draft
      redirect_to onboarding_path(step: "part_love"), alert: t("onboarding.need_more_parts")
      return
    end

    advance!(@draft, next_step_after(@step))
  end

  def optional_part?(key)
    %w[physical_world nature animals].include?(key)
  end

  def enough_parts_filled?(parts)
    filled = parts.select { |_k, v| v.is_a?(Hash) && v["ambition"].to_s.strip.present? }
    (filled.keys & %w[love family community humanity]).size >= 1
  end

  def part_filled?(key)
    ambition = @draft.dig("parts", key, "ambition").to_s.strip
    ambition.present?
  end

  def part_key_from_step(step)
    return unless step.to_s.start_with?("part_")

    step.to_s.delete_prefix("part_")
  end

  def next_step_after(step)
    index = FLOW.index(step)
    FLOW[index + 1] || "intro"
  end

  def advance!(draft, next_step)
    session[:onboarding_draft] = draft
    session[:onboarding_step] = next_step
    redirect_to onboarding_path(step: next_step)
  end

  def fail_step(step)
    session[:onboarding_draft] = @draft
    redirect_to onboarding_path(step: step), alert: t("onboarding.required")
  end

  def default_steps
    [
      t("onboarding.default_steps.one"),
      t("onboarding.default_steps.two"),
      t("onboarding.default_steps.three")
    ]
  end

  def finalize!(draft)
    ActiveRecord::Base.transaction do
      dream = current_user.dreams.create!(title: draft["dream"])
      areas = LifeArea.ensure_for_dream!(dream)

      Array(draft["parts"]).each do |key, data|
        next unless data.is_a?(Hash)

        area = areas.find { |a| a.key == key }
        next unless area

        area.update!(
          ambition: data["ambition"].to_s.strip.presence,
          present_scene: data["present_scene"].to_s.strip.presence,
          meta: data["meta"].is_a?(Hash) ? data["meta"] : {}
        )
      end

      focus_key = draft["focus_key"].presence || areas.find(&:filled?)&.key || "love"
      focus_area = areas.find { |a| a.key == focus_key } || areas.first

      goal = current_user.goals.create!(
        dream: dream,
        life_area: focus_area,
        title: draft["goal"],
        position: 0
      )
      steps = Array(draft["steps"]).each_with_index.map do |title, index|
        current_user.steps.create!(goal: goal, title: title, position: index)
      end
      first_step = steps.first
      building = current_user.buildings.create!(step: first_step, title: draft["building"], status: "active")
      Array(draft["actions"]).each_with_index do |title, index|
        current_user.today_actions.create!(
          building: building,
          title: title,
          scheduled_on: Date.current,
          position: index
        )
      end
      current_user.update!(
        focus_building: building,
        onboarding_completed_at: Time.current
      )
    end
    session.delete(:onboarding_draft)
    session.delete(:onboarding_step)
  end
end
