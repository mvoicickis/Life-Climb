# frozen_string_literal: true

module Strategy
  # Hidden per-journey Plan + path camp for battles with no chosen project.
  class HoldingProject
    class Error < StandardError; end

    def self.ensure!(user:, journey:)
      new(user:, journey:).ensure!
    end

    def initialize(user:, journey:)
      @user = user
      @journey = journey
    end

    def ensure!
      raise Error, I18n.t("strategy.need_goal") if @journey.blank?

      goal = root_goal
      raise Error, I18n.t("strategy.need_goal") if goal.blank?

      plan = find_or_create_holding!(
        horizon: "plan",
        parent: goal,
        title: I18n.t("strategy.holding.plan_title")
      )
      find_or_create_holding!(
        horizon: "project",
        parent: plan,
        title: I18n.t("strategy.holding.project_title")
      )
    end

    private

    def root_goal
      @user.strategy_goals
        .for_area(@journey.life_area_id)
        .for_kind("goal")
        .roots
        .first
    end

    def find_or_create_holding!(horizon:, parent:, title:)
      found = @user.strategy_goals.find_by(
        life_journey_id: @journey.id,
        horizon: horizon,
        holding: true
      )
      return found if found

      parent.children.create!(
        user: @user,
        life_area: @journey.life_area,
        life_journey: @journey,
        horizon: horizon,
        title: title,
        holding: true,
        position: next_position(parent)
      )
    rescue ActiveRecord::RecordNotUnique
      @user.strategy_goals.find_by!(
        life_journey_id: @journey.id,
        horizon: horizon,
        holding: true
      )
    end

    def next_position(parent)
      parent.children.maximum(:position).to_i + 1
    end
  end
end
