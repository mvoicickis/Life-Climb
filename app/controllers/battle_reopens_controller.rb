# frozen_string_literal: true

# Undo a Mountain battle win (reopen day + daily todo).
class BattleReopensController < ApplicationController
  include MountainSheetRefresh

  def create
    battle = current_user.strategy_goals.battles.find(params[:id])
    journey = battle.life_journey || current_user.primary_focused_journey

    ActiveRecord::Base.transaction do
      battle.reopen!
      todo = current_user.daily_todos.find_by(strategy_goal_id: battle.id)
      todo&.update!(completed_at: nil)
      Strategy::SyncCompletion.resync!(node: battle.parent) if battle.parent
    end

    respond_to_reopen(journey, battle)
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end

  private

  def respond_to_reopen(journey, battle)
    assign_mountain_sheet_for!(battle)
    @journey = journey || @journey
    @battle = battle.reload
    respond_to do |format|
      format.turbo_stream { render :create, status: :ok }
      format.html do
        redirect_to mountain_return_path(journey, battle),
                    notice: t("strategy.rpg.trail.battle_reopened"),
                    status: :see_other
      end
    end
  end

  def mountain_return_path(journey, battle)
    project = battle.parent
    plan = project&.parent
    goal = plan&.parent || project&.root_goal
    life_journey_path(
      journey,
      goal_id: goal&.id,
      plan_id: plan&.id,
      focus_id: project&.id
    )
  end
end
