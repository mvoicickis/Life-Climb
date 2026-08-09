# frozen_string_literal: true

module Strategy
  # Single "what should this person do right now?" resolver for Mountain,
  # Today, and (later) notifications.
  #
  # Priority: scored companion signals (overdue / streak / unlock / stalled),
  # then the legacy structural chain with a steady tone.
  #
  # Today authority is DailyTodo (for_day), matching Today / mark-done / morning
  # nudge — not strategy day nodes with scheduled_on.
  class NextAction
    OVERDUE_AFTER_HOUR = 18
    UNLOCK_WINDOW_DAYS = 3
    QUEST_STALL_DAYS = 3

    SIGNAL_ORDER = %i[battle_overdue streak_at_risk project_unlocked quest_stalled].freeze

    Result = Struct.new(
      :key,
      :title,
      :cta_label,
      :href,
      :todo_title,
      :project_title,
      :tone,
      :urgency,
      :streak_days,
      keyword_init: true
    )

    Signal = Struct.new(
      :key,
      :urgency,
      :tone,
      :todo_title,
      :project_title,
      :href,
      :streak_days,
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

      signal = best_signal
      return result_from(signal) if signal

      legacy_result_with_tone(:steady)
    end

    private

    def resolve_goal
      return nil if @user.blank? || @journey.blank?

      @user.strategy_goals.for_area(@journey.life_area_id).for_kind("goal").roots.first
    end

    def helpers
      Rails.application.routes.url_helpers
    end

    def todays_todos
      @todays_todos ||= @user.daily_todos.for_day(Date.current).ordered.to_a
    end

    def best_signal
      candidates = [
        signal_battle_overdue,
        signal_streak_at_risk,
        signal_project_unlocked,
        signal_quest_stalled
      ].compact

      return nil if candidates.empty?

      candidates.max_by { |signal| [ signal.urgency, -SIGNAL_ORDER.index(signal.key) ] }
    end

    def signal_battle_overdue
      return nil if Time.current.hour < OVERDUE_AFTER_HOUR

      todo = todays_todos.reject(&:completed?).first
      return nil if todo.nil?

      Signal.new(
        key: :battle_overdue,
        urgency: 100,
        tone: :urgent,
        todo_title: todo.title,
        href: helpers.dashboard_path
      )
    end

    def signal_streak_at_risk
      status = Climb::Streak.status(user: @user)
      on = @user.climb_streak_on
      return nil if status.days.to_i <= 0
      return nil unless on == Date.current - 1
      return nil if todays_todos.any?(&:completed?)

      Signal.new(
        key: :streak_at_risk,
        urgency: 90,
        tone: :urgent,
        streak_days: status.days,
        href: helpers.dashboard_path
      )
    end

    def signal_project_unlocked
      plan = @goal.children.for_kind("plan").ordered.first
      return nil if plan.blank?

      trail = Strategy::Trail.for(plan: plan)
      current = trail.current_node
      return nil if current.blank? || current.state != :current
      return nil if current.record.blank? || current.record.completed?

      prev = trail.nodes
        .select { |node| node.position < current.position && !tracker_linked_record?(node.record) }
        .max_by(&:position)
      return nil if prev.blank? || prev.record.blank?
      return nil if prev.record.completed_at.blank?
      return nil if prev.record.completed_at < UNLOCK_WINDOW_DAYS.days.ago

      Signal.new(
        key: :project_unlocked,
        urgency: 80,
        tone: :discovery,
        project_title: current.title,
        href: helpers.life_journey_path(@journey)
      )
    end

    def signal_quest_stalled
      todo = todays_todos.reject(&:completed?).find { |row| quest_todo?(row) }
      return nil if todo.nil?

      day = todo.strategy_goal
      return nil if day.blank?

      last_touch = quest_last_touch(day)
      return nil if last_touch.blank?
      return nil if last_touch.to_date > Date.current - QUEST_STALL_DAYS

      Signal.new(
        key: :quest_stalled,
        urgency: 60,
        tone: :discovery,
        todo_title: todo.title,
        href: helpers.dashboard_path
      )
    end

    def quest_todo?(todo)
      day = todo.strategy_goal
      day.present? && day.practice_tasks.any?
    end

    def quest_last_touch(day)
      stamps = [ day.updated_at ]
      stamps.concat(day.practice_tasks.map(&:updated_at))
      stamps.compact.max
    end

    def tracker_linked_record?(record)
      return false if record.blank?
      return record.tracker_linked? if record.respond_to?(:tracker_linked?)

      false
    end

    def result_from(signal)
      title_key = "strategy.next_action.#{signal.key}.title"
      title =
        case signal.key
        when :battle_overdue, :quest_stalled
          I18n.t(title_key, title: signal.todo_title)
        when :project_unlocked
          I18n.t(title_key, title: signal.project_title)
        when :streak_at_risk
          I18n.t(title_key, count: signal.streak_days)
        else
          I18n.t(title_key)
        end

      Result.new(
        key: signal.key,
        title: title,
        cta_label: I18n.t("strategy.next_action.#{signal.key}.cta"),
        href: signal.href,
        todo_title: signal.todo_title,
        project_title: signal.project_title,
        tone: signal.tone,
        urgency: signal.urgency,
        streak_days: signal.streak_days
      )
    end

    def legacy_result_with_tone(tone)
      result = legacy_resolve
      return nil if result.nil?

      result.tone = tone
      result.urgency = 0
      result
    end

    def legacy_resolve
      return plan_route if @goal.children.for_kind("plan").none?

      todos = todays_todos
      return set_today if todos.empty?

      incomplete = todos.reject(&:completed?)
      return complete_battle(incomplete.first) if incomplete.any?

      pending = pending_camp
      return confirm_camp(pending) if pending

      day_won
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
