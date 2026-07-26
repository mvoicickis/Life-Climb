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
      goals = @user.strategy_goals.for_area(area.id).ordered
      goal = goals.for_kind("goal").roots.first

      if goal.nil?
        return payload(
          label: I18n.t("dash.strategy_handoff.lock_goal"),
          href: Rails.application.routes.url_helpers.life_journey_path(@journey)
        )
      end

      plan = goal.children.for_kind("plan").ordered.first
      if plan.nil?
        return payload(
          label: I18n.t("dash.strategy_handoff.add_plan", goal: goal.title),
          href: Rails.application.routes.url_helpers.life_journey_path(@journey)
        )
      end

      month_parent = plan
      project = plan.children.for_kind("project").ordered.first
      month_parent = project if project

      slots = Strategy::YearCycle.remaining_month_slots(target: goal.due_on)
      current_slot = slots.find { |s| s[:month] == Date.current.month && s[:year] == Date.current.year } || slots.first
      months = month_parent.children.for_kind("month").ordered.to_a
      current_month = current_slot && months.find { |m| m.due_on == current_slot[:due_on] }

      if current_slot && current_month.nil?
        return payload(
          label: I18n.t(
            "dash.strategy_handoff.plan_month",
            month: current_slot[:label],
            plan: plan.title
          ),
          href: Rails.application.routes.url_helpers.life_journey_path(@journey, focus_id: month_parent.id)
        )
      end

      focus_month = current_month || months.min_by(&:progress_percent)
      if focus_month && focus_month.children.for_kind("day").none?
        return payload(
          label: I18n.t(
            "dash.strategy_handoff.add_battle",
            month: focus_month.title,
            plan: plan.title
          ),
          href: Rails.application.routes.url_helpers.life_journey_path(@journey, focus_id: focus_month.id)
        )
      end

      payload(
        label: I18n.t("dash.strategy_handoff.open_strategy"),
        href: Rails.application.routes.url_helpers.life_journey_path(@journey)
      )
    end

    private

    def payload(label:, href:)
      { label: label, href: href }
    end
  end
end
