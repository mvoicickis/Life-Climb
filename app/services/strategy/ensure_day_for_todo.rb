# frozen_string_literal: true

module Strategy
  # Links an orphan DailyTodo to a day StrategyGoal so practice_tasks can hang off it.
  # Idempotent: find_or_create_by user + scheduled_on + title; never creates a second DailyTodo.
  class EnsureDayForTodo
    class Error < StandardError; end

    def self.call(todo:)
      new(todo: todo).call
    end

    def initialize(todo:)
      @todo = todo
      @user = todo.user
    end

    def call
      return @todo.strategy_goal if @todo.strategy_goal_id.present?

      journey = @user.primary_focused_journey || @user.focused_journeys.first
      raise Error, I18n.t("dash.add_step.need_journey") if journey.blank?

      project = PathProject.ensure!(user: @user, journey: journey, title: @todo.title)
      raise Error, I18n.t("dash.add_step.need_spine") if project.blank?

      parent = Battles::PracticeParent.call(user: @user, project: project)

      day = @user.strategy_goals.where(horizon: "day").find_or_create_by!(
        scheduled_on: @todo.scheduled_on,
        title: @todo.title
      ) do |goal|
        goal.life_area = journey.life_area
        goal.life_journey = journey
        goal.parent = parent
        goal.position = next_position(parent)
        goal.repeat = "none"
      end

      link_todo!(day)
      day
    end

    private

    def link_todo!(day)
      linked = @user.daily_todos.find_by(strategy_goal_id: day.id, scheduled_on: @todo.scheduled_on)
      if linked.nil?
        @todo.update!(strategy_goal_id: day.id)
      elsif linked.id != @todo.id
        # A todo already owns this day slot — keep a single DailyTodo, prefer the linked one.
        # Orphan remains unlinked; caller should not reach here for unique titles.
        raise Error, I18n.t("dash.add_step.already_linked")
      end
      # linked.id == @todo.id → already linked (retry / double-submit)
    end

    def next_position(parent)
      @user.strategy_goals.where(parent_id: parent.id, horizon: "day").maximum(:position).to_i + 1
    end
  end
end
