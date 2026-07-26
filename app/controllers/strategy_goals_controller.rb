# frozen_string_literal: true

class StrategyGoalsController < ApplicationController
  before_action :require_planning_v2
  before_action :set_life_area, only: :create

  def create
    parent = find_parent
    kind = params.require(:horizon).to_s
    kind = "goal" if kind == "year"
    unless StrategyGoal::KINDS.include?(kind)
      redirect_back fallback_location: dashboard_path, alert: t("strategy.bad_horizon") and return
    end

    if parent.nil? && kind != "goal"
      redirect_back fallback_location: dashboard_path, alert: t("strategy.need_goal") and return
    end

    if parent && !parent.allowed_child_kinds.include?(kind)
      redirect_back fallback_location: dashboard_path, alert: t("strategy.bad_parent") and return
    end

    goal = current_user.strategy_goals.new(
      life_area: @life_area,
      life_journey_id: params[:life_journey_id].presence || parent&.life_journey_id,
      parent: parent,
      horizon: kind,
      title: params.require(:title).to_s.strip,
      description: params[:description].to_s.strip.presence,
      due_on: parse_due_on(kind, parent),
      scheduled_on: parse_scheduled_on(kind),
      position: next_position(parent, kind)
    )

    if goal.save
      notice = Strategy::Celebrate.call(user: current_user, goal: goal)
      Strategy::CascadeToDaily.call(user: current_user, life_area: @life_area) if goal.day?

      redirect_to strategy_redirect_path(focus_id: redirect_focus_id(goal)),
                  notice: notice, status: :see_other
    else
      redirect_to strategy_redirect_path(focus_id: parent&.id),
                  alert: goal.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    goal = current_user.strategy_goals.find(params[:id])
    area_id = goal.life_area_id
    parent_id = goal.parent_id
    goal.destroy!
    redirect_to strategy_redirect_path(area_id: area_id, focus_id: parent_id),
                notice: t("strategy.removed"), status: :see_other
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

  def parse_due_on(kind, parent)
    case kind
    when "goal"
      Strategy::YearCycle.target_dec29
    when "month"
      raw = params[:due_on].presence
      return Date.parse(raw.to_s) if raw

      if parent&.project? || parent&.plan?
        used = parent.children.for_kind("month").pluck(:due_on)
        slot = Strategy::YearCycle.remaining_month_slots(
          target: parent.root_goal&.due_on || Strategy::YearCycle.target_dec29
        ).find { |s| !used.include?(s[:due_on]) }
        return slot&.fetch(:due_on) || parent.root_goal&.due_on
      end

      parent&.due_on || Strategy::YearCycle.target_dec29
    when "week", "plan", "project"
      raw = params[:due_on].presence
      raw ? Date.parse(raw.to_s) : parent&.due_on
    end
  rescue ArgumentError, TypeError
    parent&.due_on
  end

  def parse_scheduled_on(kind)
    return unless kind == "day"

    Date.parse(params[:scheduled_on].presence || Date.current.to_s)
  rescue ArgumentError, TypeError
    Date.current
  end

  def next_position(parent, kind)
    scope = current_user.strategy_goals.where(life_area_id: @life_area.id).for_kind(kind)
    scope = parent ? scope.where(parent_id: parent.id) : scope.roots
    scope.maximum(:position).to_i + 1
  end

  def redirect_focus_id(goal)
    case goal.kind
    when "goal" then goal.id
    when "plan", "project", "month", "week", "day" then goal.parent_id
    else goal.parent_id
    end
  end

  def strategy_redirect_path(area_id: @life_area.id, focus_id: nil)
    journey = current_user.life_journeys.active.find_by(life_area_id: area_id) ||
              current_user.primary_focused_journey
    if journey
      life_journey_path(journey, focus_id: focus_id)
    else
      new_life_journey_path(life_area_id: area_id)
    end
  end
end
