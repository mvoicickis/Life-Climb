# frozen_string_literal: true

class StrategyGoalsController < ApplicationController
  before_action :require_planning_v2
  before_action :set_life_area, only: :create

  def create
    parent = find_parent
    horizon = params.require(:horizon).to_s
    unless StrategyGoal::HORIZONS.include?(horizon)
      redirect_back fallback_location: dashboard_path, alert: t("strategy.bad_horizon") and return
    end

    goal = current_user.strategy_goals.new(
      life_area: @life_area,
      life_journey_id: params[:life_journey_id].presence || parent&.life_journey_id,
      parent: parent,
      horizon: horizon,
      title: params.require(:title).to_s.strip,
      scheduled_on: parse_scheduled_on(horizon),
      position: next_position(parent, horizon)
    )

    if goal.save
      amount = parent.present? ? GameRules::STRATEGY_CHILD_SP : GameRules::STRATEGY_LOCK_SP
      Strategy::Award.call(
        user: current_user,
        amount: amount,
        reason: I18n.t("strategy.sp_reason", title: goal.title, horizon: I18n.t("strategy.horizons.#{horizon}")),
        source: goal
      )

      Strategy::CascadeToDaily.call(user: current_user, life_area: @life_area) if horizon == "day"

      if week_breakdown_complete?(goal)
        Strategy::Award.call(
          user: current_user,
          amount: GameRules::STRATEGY_WEEK_BREAKDOWN_SP,
          reason: "week_breakdown",
          source: goal.parent
        )
      end

      redirect_to strategy_redirect_path, notice: t("strategy.created", sp: amount), status: :see_other
    else
      redirect_to strategy_redirect_path, alert: goal.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    goal = current_user.strategy_goals.find(params[:id])
    area_id = goal.life_area_id
    goal.destroy!
    redirect_to strategy_redirect_path(area_id: area_id), notice: t("strategy.removed"), status: :see_other
  end

  private

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path
  end

  def set_life_area
    @life_area = current_user.life_areas.find(params.require(:life_area_id))
  end

  def find_parent
    return if params[:parent_id].blank?

    current_user.strategy_goals.find(params[:parent_id])
  end

  def parse_scheduled_on(horizon)
    return unless horizon == "day"

    Date.parse(params.require(:scheduled_on).to_s)
  rescue ArgumentError, TypeError
    Date.current
  end

  def next_position(parent, horizon)
    scope = current_user.strategy_goals.where(life_area_id: @life_area.id, horizon: horizon)
    scope = parent ? scope.where(parent_id: parent.id) : scope.roots
    scope.maximum(:position).to_i + 1
  end

  def week_breakdown_complete?(goal)
    return false unless goal.horizon == "day"
    return false if goal.parent.blank? || goal.parent.horizon != "week"

    week = goal.parent
    return false if week.children.for_horizon("day").count < 3

    current_user.strategy_point_ledgers.where(source: week, reason: "week_breakdown").none?
  end

  def strategy_redirect_path(area_id: @life_area.id)
    journey = current_user.life_journeys.active.find_by(life_area_id: area_id) ||
              current_user.primary_focused_journey
    if journey
      life_journey_path(journey, area: journey.life_area.key)
    else
      new_life_journey_path(life_area_id: area_id)
    end
  end
end
