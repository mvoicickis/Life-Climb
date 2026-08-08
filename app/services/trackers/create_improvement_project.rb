# frozen_string_literal: true

module Trackers
  # Creates a path-level Project under the Habit's Mountain (or primary Journey)
  # and links it via strategy_goals.habit_id.
  class CreateImprovementProject
    class Error < StandardError; end

    def self.call(user:, habit:)
      new(user: user, habit: habit).call
    end

    def initialize(user:, habit:)
      @user = user
      @habit = habit
    end

    def call
      raise Error, I18n.t("areas.improve.need_attention") unless @habit.attention?

      journey = resolve_journey
      raise Error, I18n.t("areas.improve.need_journey") if journey.blank?

      goal = @user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
      raise Error, I18n.t("areas.improve.need_goal") if goal.blank?

      plan = resolve_plan(goal, journey)
      position = plan.children.for_kind("project").maximum(:position).to_i + 1

      project = @user.strategy_goals.create!(
        life_area: journey.life_area,
        life_journey: journey,
        parent: plan,
        horizon: "project",
        title: I18n.t("areas.improve.project_title", name: @habit.name.to_s.truncate(80)),
        habit: @habit,
        position: position
      )
      Strategy::SyncCompletion.resync!(node: project)
      project
    end

    private

    def resolve_journey
      @habit.life_journey ||
        @user.primary_focused_journey ||
        @user.life_journeys.active.order(:id).first
    end

    def resolve_plan(goal, journey)
      plans = goal.children.for_kind("plan").ordered.to_a
      open = plans.find { |plan| plan.completed_at.blank? }
      return open if open
      return plans.first if plans.any?

      @user.strategy_goals.create!(
        life_area: journey.life_area,
        life_journey: journey,
        parent: goal,
        horizon: "plan",
        title: I18n.t(
          "areas.improve.plan_title",
          name: (@habit.area&.name.presence || @habit.name).to_s.truncate(60)
        ),
        position: goal.children.for_kind("plan").maximum(:position).to_i + 1
      )
    end
  end
end
