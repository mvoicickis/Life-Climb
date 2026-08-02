# frozen_string_literal: true

# Objectives inside a Practice quest folder on Mountain.
class PracticeTasksController < ApplicationController
  before_action :require_planning_v2

  def create
    practice = current_user.strategy_goals.battles.find(params[:strategy_goal_id])
    task = practice.practice_tasks.new(
      user: current_user,
      title: params.require(:title).to_s.strip,
      position: next_position(practice)
    )

    if task.save
      redirect_to mountain_focus_path(practice),
                  notice: t("strategy.rpg.objective_added"),
                  status: :see_other
    else
      redirect_to mountain_focus_path(practice),
                  alert: task.errors.full_messages.to_sentence.presence || t("strategy.rpg.objective_add_failed"),
                  status: :see_other
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end

  def update
    task = current_user.practice_tasks.find(params[:id])
    practice = task.strategy_goal

    if ActiveModel::Type::Boolean.new.cast(params[:completed])
      task.complete!
    else
      task.reopen!
    end

    redirect_to mountain_focus_path(practice), status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end

  private

  def next_position(practice)
    (practice.practice_tasks.maximum(:position) || -1) + 1
  end

  def mountain_focus_path(practice)
    camp = practice.parent
    plan = camp&.parent&.plan? ? camp.parent : camp&.ancestor_chain&.reverse&.find(&:plan?)
    goal = plan&.parent || camp&.root_goal
    journey = practice.life_journey ||
              current_user.life_journeys.active.find_by(life_area_id: practice.life_area_id) ||
              current_user.primary_focused_journey

    return dashboard_path if journey.blank?

    life_journey_path(
      journey,
      goal_id: goal&.id,
      plan_id: plan&.id,
      focus_id: camp&.id
    )
  end

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path
  end
end
