# frozen_string_literal: true

module Strategy
  # Single "what should this person do right now?" resolver for Mountain,
  # Today, and (later) notifications. Controllers still use their own checks
  # until PR2/PR3 switch call sites over.
  #
  # Today authority is DailyTodo (for_day), matching Today / mark-done / morning
  # nudge — not strategy day nodes with scheduled_on. Those two can disagree
  # until CascadeToDaily runs; that sync gap is intentional follow-up, not fixed here.
  class NextAction
    Result = Struct.new(
      :key,
      :title,
      :cta_label,
      :href,
      :todo_title,
      :project_title,
      keyword_init: true
    )

    def self.for(user:, session: nil, journey: nil)
      new(user:, session:, journey:).call
    end

    def initialize(user:, session: nil, journey: nil)
      @user = user
      @session = session
      @journey = journey || user&.primary_focused_journey
      @goal = resolve_goal
    end

    def call
      return nil if @journey.blank? || @goal.blank?

      # Dashboard-style first-climb check (for_kind scope).
      return plan_route if @goal.children.for_kind("plan").none?

      todos = @user.daily_todos.for_day(Date.current).ordered.to_a
      return set_today if todos.empty?

      incomplete = todos.reject(&:completed?)
      return complete_battle(incomplete.first) if incomplete.any?

      pending = pending_camp
      return confirm_camp(pending) if pending

      day_won
    end

    private

    def resolve_goal
      return nil if @user.blank? || @journey.blank?

      @user.strategy_goals.for_area(@journey.life_area_id).for_kind("goal").roots.first
    end

    def helpers
      Rails.application.routes.url_helpers
    end

    def plan_route
      Result.new(
        key: :plan_route,
        title: I18n.t("strategy.next_action.plan_route.title"),
        cta_label: I18n.t("strategy.next_action.plan_route.cta"),
        href: helpers.life_journey_path(@journey)
      )
    end

    def set_today
      Result.new(
        key: :set_today,
        title: I18n.t("strategy.next_action.set_today.title"),
        cta_label: I18n.t("strategy.next_action.set_today.cta"),
        href: helpers.dashboard_path
      )
    end

    def complete_battle(todo)
      Result.new(
        key: :complete_battle,
        title: I18n.t("strategy.next_action.complete_battle.title", title: todo.title),
        cta_label: I18n.t("strategy.next_action.complete_battle.cta"),
        href: helpers.dashboard_path,
        todo_title: todo.title
      )
    end

    def confirm_camp(project)
      Result.new(
        key: :confirm_camp,
        title: I18n.t("strategy.next_action.confirm_camp.title", title: project.title),
        cta_label: I18n.t("strategy.next_action.confirm_camp.cta"),
        href: helpers.dashboard_path,
        project_title: project.title
      )
    end

    def day_won
      Result.new(
        key: :day_won,
        title: I18n.t("strategy.next_action.day_won.title"),
        cta_label: I18n.t("strategy.next_action.day_won.cta"),
        href: helpers.life_journey_path(@journey)
      )
    end

    def pending_camp
      return nil if @session.nil?

      Strategy::ProjectCheckQueue.next_for(user: @user, session: @session)
    end
  end
end
