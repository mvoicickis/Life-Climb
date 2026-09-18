# frozen_string_literal: true

# Restore the last destroyed strategy goal from a short-lived session stash (Mountain undo toast).
# Limitation: restores one flat node snapshot only (no deep child tree). TTL 5 seconds.
class StrategyGoalRestoresController < ApplicationController
  include CampArrangementTrailRefresh

  TTL_SECONDS = 5

  def create
    stash = session[:last_destroyed_goal]
    session.delete(:last_destroyed_goal)

    if stash.blank? || stash["user_id"].to_i != current_user.id
      return restore_fail(alert: t("strategy.rpg.trail.undo_expired"))
    end

    stamped = stash["stamped_at"].to_i
    if stamped <= 0 || (Time.current.to_i - stamped) > TTL_SECONDS
      return restore_fail(alert: t("strategy.rpg.trail.undo_expired"))
    end

    attrs = stash.fetch("attrs")
    reparented_battle_ids = Array(stash["reparented_battle_ids"]).map(&:to_i)
    goal = current_user.strategy_goals.new(attrs)
    goal.stage_explicit = true if goal.project?
    goal.save!

    if goal.project? && reparented_battle_ids.any?
      restore_battles_from_holding!(goal:, battle_ids: reparented_battle_ids)
    end

    Strategy::CascadeToDaily.call(user: current_user, life_area: goal.life_area) if goal.day?
    Strategy::SyncCompletion.resync!(node: goal.parent) if goal.parent

    plan = goal.parent if goal.project? && goal.parent&.plan?
    plan ||= goal.ancestor_chain.reverse.find(&:plan?) if goal.project?
    if plan.present?
      journey = goal.life_journey || current_user.primary_focused_journey
      assign_camp_arrangement_trail_refresh!(
        plan: plan,
        journey: journey,
        arrange_overlay_open: params[:arrange_open].present?
      )
    end

    respond_to do |format|
      format.turbo_stream { render :create }
      format.html do
        redirect_to restore_return_path(goal),
                    notice: t("strategy.rpg.trail.restored", title: goal.title),
                    status: :see_other
      end
    end
  rescue ActiveRecord::RecordInvalid, KeyError, TypeError
    restore_fail(alert: t("strategy.rpg.trail.undo_expired"))
  end

  private

  def restore_battles_from_holding!(goal:, battle_ids:)
    journey = goal.life_journey || current_user.primary_focused_journey
    holding = Strategy::HoldingProject.ensure!(user: current_user, journey: journey)

    current_user.strategy_goals.where(
      id: battle_ids,
      horizon: "day",
      parent_id: holding.id
    ).find_each do |battle|
      battle.update!(parent: goal)
      Strategy::CascadeToDaily.sync_goal!(user: current_user, goal: battle)
    end
  end

  def restore_fail(alert:)
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_back_fallback(alert: alert) }
    end
  end

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
