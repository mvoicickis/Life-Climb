# frozen_string_literal: true

module Battles
  # Creates today's Battle from a category first-climb example, then cascades to Today.
  class QuickAddToday
    class Error < StandardError; end

    Result = Struct.new(:todo, :battle, :title, :category, keyword_init: true)

    def self.call(user:, category: nil, title: nil)
      new(user: user, category: category, title: title).call
    end

    def initialize(user:, category: nil, title: nil)
      @user = user
      @explicit_category = category
      @forced_title = title
    end

    def call
      journey = @user.primary_focused_journey || @user.focused_journeys.first
      raise Error, I18n.t("notifications.actions.need_journey") if journey.blank?

      category = Onboarding::Categories.resolve_for(user: @user, explicit: @explicit_category)
      title = @forced_title.presence || example_title_for(category)

      project = path_project_for(journey)
      raise Error, I18n.t("notifications.actions.need_spine") if project.blank?

      parent = PracticeParent.call(user: @user, project: project)
      battle = @user.strategy_goals.create!(
        life_area: journey.life_area,
        life_journey: journey,
        parent: parent,
        horizon: "day",
        title: title,
        scheduled_on: Date.current,
        position: next_position(parent)
      )

      Strategy::CascadeToDaily.call(user: @user, life_area: journey.life_area)
      todo = @user.daily_todos.find_by!(strategy_goal_id: battle.id, scheduled_on: Date.current)

      Result.new(todo: todo, battle: battle, title: title, category: category)
    end

    private

    def example_title_for(category)
      examples = Array(I18n.t("strategy.first_climb.examples.#{category}.action", default: []))
      raise Error, I18n.t("notifications.actions.need_example") if examples.empty?

      examples.sample
    end

    def path_project_for(journey)
      area = journey.life_area
      goal = @user.strategy_goals.for_area(area.id).for_kind("goal").roots.first
      return if goal.blank?

      plan = goal.children.for_kind("plan").ordered.first
      return if plan.blank?

      plan.children.for_kind("project").ordered.find(&:path_level_camp?) ||
        plan.children.for_kind("project").ordered.first
    end

    def next_position(parent)
      @user.strategy_goals.where(parent_id: parent.id, horizon: "day").maximum(:position).to_i + 1
    end
  end
end
