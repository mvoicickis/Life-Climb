# frozen_string_literal: true

# Win one Strategy battle from the Mountain world map, then return to the climb.
class BattleWinsController < ApplicationController
  include MountainSheetRefresh
  def create
    battle = current_user.strategy_goals.battles.find(params[:id])
    journey = battle.life_journey || current_user.primary_focused_journey

    if battle.quantified_path_project.present?
      redirect_to mountain_return_path(journey, battle),
                  alert: t("strategy.rpg.trail.log_needed"),
                  status: :see_other and return
    end

    result = Battles::WinFromMountain.call(battle: battle, user: current_user, session: session)
    result.flash.each { |key, value| flash[key] = value }

    respond_to_quick_win(journey, result.battle, awarded: result.awarded)
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end

  private

  def respond_to_quick_win(journey, battle, awarded:)
    assign_mountain_sheet_for!(battle)
    @journey = journey || @journey
    @awarded = awarded
    @battle = battle.reload
    @quiet_win = params[:source] == "camp_sheet"
    if @quiet_win && @project.present?
      days = @project.children.select { |child| child.day? && !child.holding? }
      @done_days = days.select { |day| helpers.mountain_trail_done_today?(day) }
                           .sort_by { |d| [ d.scheduled_on || Date.new(9999), d.position.to_i, d.id ] }
    end
    respond_to do |format|
      format.turbo_stream do
        flash.discard(:ap_gained)
        flash.discard(:battle_celebrate)
        flash.discard(:climb_boss)
        flash.discard(:climb_reward)
        render :create, status: :ok
      end
      format.html do
        redirect_to mountain_return_path(journey, battle),
                    notice: I18n.t("battle.completed_notice", lp: awarded),
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
