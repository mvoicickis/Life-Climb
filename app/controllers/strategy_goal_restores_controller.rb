# frozen_string_literal: true

# Restore the last destroyed strategy goal from a short-lived session stash (Mountain undo toast).
# Limitation: restores one flat node snapshot only (no deep child tree). TTL 5 seconds.
class StrategyGoalRestoresController < ApplicationController
  TTL_SECONDS = 5

  def create
    stash = session[:last_destroyed_goal]
    session.delete(:last_destroyed_goal)

    if stash.blank? || stash["user_id"].to_i != current_user.id
      redirect_back_fallback(alert: t("strategy.rpg.trail.undo_expired")) and return
    end

    stamped = stash["stamped_at"].to_i
    if stamped <= 0 || (Time.current.to_i - stamped) > TTL_SECONDS
      redirect_back_fallback(alert: t("strategy.rpg.trail.undo_expired")) and return
    end

    attrs = stash.fetch("attrs")
    goal = current_user.strategy_goals.new(attrs)
    goal.save!

    Strategy::CascadeToDaily.call(user: current_user, life_area: goal.life_area) if goal.day?
    Strategy::SyncCompletion.resync!(node: goal.parent) if goal.parent

    redirect_to restore_return_path(goal),
                notice: t("strategy.rpg.trail.restored", title: goal.title),
                status: :see_other
  rescue ActiveRecord::RecordInvalid, KeyError, TypeError
    redirect_back_fallback(alert: t("strategy.rpg.trail.undo_expired"))
  end

  private

  def restore_return_path(goal)
    journey = goal.life_journey || current_user.primary_focused_journey
    case goal.kind
    when "project"
      plan = goal.parent&.plan? ? goal.parent : goal.ancestor_chain.reverse.find(&:plan?)
      life_journey_path(journey, goal_id: goal.root_goal&.id, plan_id: plan&.id, focus_id: goal.id)
    when "day"
      project = goal.parent
      plan = project&.parent
      life_journey_path(journey, goal_id: goal.root_goal&.id, plan_id: plan&.id, focus_id: project&.id)
    else
      life_journey_path(journey)
    end
  end

  def redirect_back_fallback(alert:)
    redirect_to(request.referer.presence || dashboard_path, alert: alert, status: :see_other)
  end
end
