# frozen_string_literal: true

# Mountain sticky mark-complete / reopen for Plans and Projects.
class StrategyGoalCompletionsController < ApplicationController
  include MountainSheetRefresh

  before_action :require_planning_v2
  before_action :set_goal
  before_action :reject_holding

  def create
    unless @goal.plan? || @goal.project? || @goal.goal?
      return respond_invalid
    end

    @goal.manually_complete!
    Strategy::SyncCompletion.resync!(node: @goal)
    assign_completion_stream_context!
    respond_to do |format|
      format.turbo_stream { render :create, status: :ok }
      format.html { redirect_to mountain_return_path, status: :see_other }
    end
  rescue ActiveRecord::RecordInvalid
    respond_failure
  end

  def destroy
    unless @goal.plan? || @goal.project?
      return respond_invalid
    end

    @goal.manually_reopen!
    Strategy::SyncCompletion.resync!(node: @goal)
    assign_completion_stream_context!
    respond_to do |format|
      format.turbo_stream { render :destroy, status: :ok }
      format.html { redirect_to mountain_return_path, status: :see_other }
    end
  rescue ActiveRecord::RecordInvalid
    respond_failure
  end

  private

  def set_goal
    @goal = current_user.strategy_goals.find(params[:strategy_goal_id])
    @completion_target = @goal
  end

  def reject_holding
    return unless @goal.holding?

    redirect_to fallback_path, alert: t("strategy.rpg.manual_complete_invalid"), status: :see_other
    throw :abort
  end

  def assign_completion_stream_context!
    assign_mountain_sheet_for!(@goal.reload)
    @project = @goal if @goal.project?
    return if @plan.blank?

    open_camps = helpers.mountain_trail_open_camps(@plan)
    open_camps = open_camps.reject { |camp| camp.id == @project&.id }
    @next_camp = helpers.mountain_trail_next_camp(open_camps)
    @mount_next_camp_sheet = next_camp_needs_sheet_mount?
  end

  def next_camp_needs_sheet_mount?
    return false if @next_camp.blank? || @plan.blank?

    trail = Strategy::Trail.for(plan: @plan, ensure_visible_id: @next_camp.id)
    !helpers.mountain_trail_sheet_camp_ids(trail).include?(@next_camp.id)
  end

  def respond_invalid
    respond_to do |format|
      format.html { redirect_to fallback_path, alert: t("strategy.rpg.manual_complete_invalid"), status: :see_other }
      format.turbo_stream { head :unprocessable_entity }
    end
  end

  def respond_failure
    respond_to do |format|
      format.html { redirect_to fallback_path, alert: t("strategy.rpg.manual_complete_invalid"), status: :see_other }
      format.turbo_stream { head :unprocessable_entity }
    end
  end

  def mountain_return_path
    target = @completion_target || @goal
    journey = current_user.life_journeys.active.find_by(life_area_id: target.life_area_id) ||
              current_user.primary_focused_journey
    return fallback_path if journey.blank?

    case target.kind
    when "goal"
      life_journey_path(journey, goal_id: target.id)
    when "plan"
      life_journey_path(journey, goal_id: target.parent_id, plan_id: target.id)
    when "project"
      plan = target.parent&.plan? ? target.parent : target.ancestor_chain.reverse.find(&:plan?)
      life_journey_path(
        journey,
        goal_id: target.root_goal&.id,
        plan_id: plan&.id,
        focus_id: target.id
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
