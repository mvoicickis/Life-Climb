# frozen_string_literal: true

module Strategy
  # One-line next-step copy for Today ↔ Strategy handoff.
  class Handoff
    def self.for(user:, journey:)
      new(user:, journey:).call
    end

    def initialize(user:, journey:)
      @user = user
      @journey = journey
    end

    def call
      return nil if @journey.blank?

      area = @journey.life_area
      goal = Goals::Current.goal_for(user: @user, journey: @journey)
      helpers = Rails.application.routes.url_helpers

      if goal.nil?
        return payload(
          step: :lock_goal,
          label: I18n.t("dash.strategy_handoff.lock_goal"),
          href: helpers.life_journey_path(@journey)
        )
      end

      plan = goal.children.for_kind("plan").not_holding.ordered.first
      if plan.nil?
        return payload(
          step: :add_plan,
          label: I18n.t("dash.strategy_handoff.add_plan", goal: goal.title),
          href: helpers.life_journey_path(@journey, notebook: 1)
        )
      end

      if Strategy::SummitReached.on_journey?(user: @user, journey: @journey)
        return payload(
          step: :summit_next_goal,
          label: I18n.t("dash.battlefield.empty_cta.summit_next_goal"),
          href: helpers.summit_next_goal_path
        )
      end

      project = PathProject.resolve(user: @user, journey: @journey)
      if project.nil?
        return payload(
          step: :add_project,
          plan_id: plan.id,
          label: I18n.t("dash.strategy_handoff.add_project", plan: plan.title),
          href: helpers.life_journey_path(@journey, focus_id: plan.id)
        )
      end

      if Strategy::Progress.battles_under(project).none?
        return payload(
          step: :add_battle,
          project_id: project.id,
          label: I18n.t("dash.strategy_handoff.add_battle", project: project.title),
          href: helpers.life_journey_path(@journey, focus_id: project.id)
        )
      end

      payload(
        step: :open_strategy,
        project_id: project.id,
        label: I18n.t("dash.strategy_handoff.open_strategy"),
        href: helpers.life_journey_path(@journey, focus_id: project.id)
      )
    end

    private

    def payload(label:, href:, step:, project_id: nil, plan_id: nil)
      { step: step, label: label, href: href, project_id: project_id, plan_id: plan_id }
    end
  end
end
