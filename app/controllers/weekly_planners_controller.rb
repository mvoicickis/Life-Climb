# frozen_string_literal: true

# UI shell around Strategy::WeeklyPlanner::Engine.
# Path ⋮ "Plan this week" is the entry (new_week: 1 restarts completed runs).
class WeeklyPlannersController < ApplicationController
  before_action :require_planning_v2
  before_action :require_journey!

  def show
    maybe_restart_for_new_week!
    @step = Strategy::WeeklyPlanner::Engine.current(
      user: current_user,
      journey: @journey,
      plan_id: params[:plan_id]
    )
    if @step.blank?
      redirect_to fallback_path, alert: t("strategy.weekly_planner.shell.need_plan"), status: :see_other
    end
  end

  def create
    value = planner_answer_value
    if value.nil?
      return render_answer_error(
        t("strategy.weekly_planner.shell.bad_answer"),
        attempted_value: ""
      )
    end

    result = Strategy::WeeklyPlanner::Engine.answer!(
      user: current_user,
      journey: @journey,
      value: value,
      plan_id: params[:plan_id]
    )

    if result.next_step.completed?
      redirect_to life_journey_path(@journey),
                  notice: result.ack.presence || t("strategy.weekly_planner.shell.done_flash",
                                                   count: result.next_step.created_count.to_i,
                                                   title: result.next_step.title.to_s),
                  status: :see_other
    else
      flash[:weekly_planner_ack] = result.ack if result.ack.present?
      redirect_to weekly_planner_path(plan_id: params[:plan_id]), status: :see_other
    end
  rescue ArgumentError => e
    render_answer_error(
      e.message.presence || t("strategy.weekly_planner.shell.bad_answer"),
      attempted_value: params[:value].to_s
    )
  end

  private

  def planner_answer_value
    intent = params[:intent].to_s.presence

    if params.key?(:dates) || params.key?("dates")
      return { action: "pick_days", dates: Array(params[:dates]) }
    end

    case intent
    when "add_item"
      { action: "add_item", title: params[:value].to_s }
    when "remove_item"
      { action: "remove_item", index: params[:index] }
    when "continue"
      items = params[:items]
      if items.present?
        { action: "continue", items: Array(items) }
      else
        { action: "continue" }
      end
    else
      # Legacy / suggestion button_to with value=task:ID or free text.
      return nil unless params.key?(:value) || params.key?("value")

      { action: "add_item", title: params[:value].to_s }
    end
  end

  def maybe_restart_for_new_week!
    return unless params[:new_week].present?

    Strategy::WeeklyPlanner::Engine.restart!(
      user: current_user,
      journey: @journey,
      plan_id: params[:plan_id]
    )
  end

  def render_answer_error(message, attempted_value:)
    @error = message
    @attempted_value = attempted_value
    @step = Strategy::WeeklyPlanner::Engine.current(
      user: current_user,
      journey: @journey,
      plan_id: params[:plan_id]
    )
    if @step.blank?
      redirect_to fallback_path, alert: t("strategy.weekly_planner.shell.need_plan"), status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

  def require_journey!
    @journey = current_user.primary_focused_journey
    return if @journey.present?

    redirect_to fallback_path, alert: t("strategy.weekly_planner.shell.need_journey"), status: :see_other
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
