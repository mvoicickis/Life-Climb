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
      goal = @user.strategy_goals.for_area(area.id).for_kind("goal").roots.first
      helpers = Rails.application.routes.url_helpers

      if goal.nil?
        return payload(
          label: I18n.t("dash.strategy_handoff.lock_goal"),
          href: helpers.life_journey_path(@journey)
        )
      end

      plan = goal.children.for_kind("plan").ordered.first
      if plan.nil?
        return payload(
          label: I18n.t("dash.strategy_handoff.add_plan", goal: goal.title),
          href: helpers.life_journey_path(@journey, notebook: 1)
        )
      end

      project = PathProject.resolve(user: @user, journey: @journey)
      if project.nil?
        return payload(
          label: I18n.t("dash.strategy_handoff.add_project", plan: plan.title),
          href: helpers.life_journey_path(@journey, focus_id: plan.id)
        )
      end

      if Strategy::Progress.battles_under(project).none?
        return payload(
          label: I18n.t("dash.strategy_handoff.add_battle", project: project.title),
          href: helpers.life_journey_path(@journey, focus_id: project.id)
        )
      end

      payload(
        label: I18n.t("dash.strategy_handoff.open_strategy"),
        href: helpers.life_journey_path(@journey, focus_id: project.id)
      )
    end

    private

    def payload(label:, href:)
      { label: label, href: href }
    end
  end
end
