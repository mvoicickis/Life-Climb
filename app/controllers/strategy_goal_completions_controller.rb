# frozen_string_literal: true

# Mountain sticky mark-complete / reopen for Plans and Projects.
# Separate from Today’s ProjectCompletionsController (post-battle check).
class StrategyGoalCompletionsController < ApplicationController
  before_action :require_planning_v2
  before_action :set_goal

  def create
    unless @goal.plan? || @goal.project?
      return redirect_to fallback_path, alert: t("strategy.rpg.manual_complete_invalid"), status: :see_other
    end

    @goal.manually_complete!
    Strategy::SyncCompletion.resync!(node: @goal)
    redirect_to mountain_return_path, notice: t("strategy.rpg.manual_complete_notice", title: @goal.title), status: :see_other
  end

  def destroy
    unless @goal.plan? || @goal.project?
      return redirect_to fallback_path, alert: t("strategy.rpg.manual_complete_invalid"), status: :see_other
    end

    @goal.manually_reopen!
    Strategy::SyncCompletion.resync!(node: @goal)
    redirect_to mountain_return_path, notice: t("strategy.rpg.manual_reopen_notice", title: @goal.title), status: :see_other
  end

  private

  def set_goal
    @goal = current_user.strategy_goals.find(params[:strategy_goal_id])
  end

  def mountain_return_path
    journey = current_user.life_journeys.active.find_by(life_area_id: @goal.life_area_id) ||
              current_user.primary_focused_journey
    return fallback_path if journey.blank?

    case @goal.kind
    when "plan"
      life_journey_path(journey, goal_id: @goal.parent_id, plan_id: @goal.id)
    when "project"
      plan = @goal.parent&.plan? ? @goal.parent : @goal.ancestor_chain.reverse.find(&:plan?)
      life_journey_path(
        journey,
        goal_id: @goal.root_goal&.id,
        plan_id: plan&.id,
        focus_id: @goal.id
      )
    else
      life_journey_path(journey)
    end
  end

  def fallback_path
    journey = current_user.primary_focused_journey
    journey ? life_journey_path(journey) : dashboard_path
  end

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path
  end
end
