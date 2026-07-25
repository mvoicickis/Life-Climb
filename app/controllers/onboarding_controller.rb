class OnboardingController < ApplicationController
  skip_onboarding_check

  def show
    redirect_to dashboard_path and return if current_user.onboarding_completed? && current_user.dreams.any?

    @step = (params[:step].presence || session[:onboarding_step] || "dream").to_s
    @step = "dream" unless %w[dream goal steps building today].include?(@step)
    session[:onboarding_step] = @step
    @draft = session[:onboarding_draft] || {}
  end

  def update
    @step = params[:step].to_s
    @draft = (session[:onboarding_draft] || {}).deep_merge(draft_params.to_h)

    case @step
    when "dream"
      return fail_step("dream") if @draft["dream"].blank?
      session[:onboarding_draft] = @draft
      session[:onboarding_step] = "goal"
      redirect_to onboarding_path(step: "goal")
    when "goal"
      return fail_step("goal") if @draft["goal"].blank?
      session[:onboarding_draft] = @draft
      session[:onboarding_step] = "steps"
      redirect_to onboarding_path(step: "steps")
    when "steps"
      steps = Array(@draft["steps"]).map { |s| s.to_s.strip }.reject(&:blank?)
      steps = default_steps if steps.empty?
      @draft["steps"] = steps
      session[:onboarding_draft] = @draft
      session[:onboarding_step] = "building"
      redirect_to onboarding_path(step: "building")
    when "building"
      return fail_step("building") if @draft["building"].blank?
      session[:onboarding_draft] = @draft
      session[:onboarding_step] = "today"
      redirect_to onboarding_path(step: "today")
    when "today"
      actions = Array(@draft["actions"]).map { |s| s.to_s.strip }.reject(&:blank?)
      return fail_step("today") if actions.empty?
      @draft["actions"] = actions
      finalize!(@draft)
      redirect_to dashboard_path, notice: t("onboarding.welcome")
    else
      redirect_to onboarding_path(step: "dream")
    end
  end

  private

  def draft_params
    params.fetch(:onboarding, {}).permit(:dream, :goal, :building, steps: [], actions: [])
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
      goal = current_user.goals.create!(dream: dream, title: draft["goal"], position: 0)
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
