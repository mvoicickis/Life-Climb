# frozen_string_literal: true

class StrategyGoalsController < ApplicationController
  before_action :require_planning_v2
  before_action :set_life_area, only: :create

  def create
    parent = find_parent
    kind = params.require(:horizon).to_s
    kind = "goal" if kind == "year"
    unless StrategyGoal::KINDS.include?(kind)
      return fail_redirect(t("strategy.bad_horizon"))
    end

    if parent.nil? && kind != "goal"
      return fail_redirect(t("strategy.need_goal"))
    end

    if parent && !parent.allowed_child_kinds.include?(kind)
      return fail_redirect(t("strategy.bad_parent"))
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
      celebration = Strategy::Celebrate.call(user: current_user, goal: goal)
      Strategy::CascadeToDaily.call(user: current_user, life_area: @life_area) if goal.day?
      if celebration[:amount].to_i.positive?
        flash[:sp_gained] = celebration[:amount]
        flash[:climb_boss] = true if celebration[:amount].to_i >= 50
      end

      @created = goal
      prepare_world_for!(goal, focus_id: redirect_focus_id(goal))
      respond_to do |format|
        format.turbo_stream { render :create, status: :created }
        format.html do
          redirect_to strategy_redirect_path(focus_id: redirect_focus_id(goal)),
                      notice: celebration[:notice], status: :see_other
        end
      end
    else
      fail_redirect(goal.errors.full_messages.to_sentence, focus_id: parent&.id)
    end
  end

  def destroy
    goal = current_user.strategy_goals.find(params[:id])
    area_id = goal.life_area_id
    parent_id = goal.parent_id
    removed_id = goal.id
    goal.destroy!
    prepare_world_for_area!(area_id, focus_id: parent_id)
    @removed_id = removed_id
    respond_to do |format|
      format.turbo_stream { render :destroy }
      format.html do
        redirect_to strategy_redirect_path(area_id: area_id, focus_id: parent_id),
                    notice: t("strategy.removed"), status: :see_other
      end
    end
  end

  def update
    goal = current_user.strategy_goals.find(params[:id])
    goal.title = params[:title].to_s.strip
    focus_id = goal.goal? ? goal.id : goal.parent_id

    if goal.save
      Strategy::CascadeToDaily.call(user: current_user, life_area: goal.life_area) if goal.day?
      @updated = goal
      prepare_world_for!(goal, focus_id: focus_id)
      respond_to do |format|
        format.turbo_stream { render :update }
        format.html do
          redirect_to strategy_redirect_path(area_id: goal.life_area_id, focus_id: focus_id),
                      notice: t("strategy.renamed"), status: :see_other
        end
      end
    else
      fail_redirect(goal.errors.full_messages.to_sentence, area_id: goal.life_area_id, focus_id: focus_id)
    end
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
    when "plan", "project"
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
    when "plan" then goal.id # Open the new plan's camp notebook, not the parent goal
    when "project", "day" then goal.id # Keep notebook on the node just created
    else goal.parent_id
    end
  end

  def strategy_redirect_path(area_id: @life_area&.id, focus_id: nil, peek: nil, sheet: nil)
    area_id ||= current_user.primary_focused_journey&.life_area_id
    journey = current_user.life_journeys.active.find_by(life_area_id: area_id) ||
              current_user.primary_focused_journey
    if journey
      life_journey_path(journey, focus_id: focus_id, peek: peek, sheet: sheet)
    else
      new_life_journey_path(life_area_id: area_id)
    end
  end

  def fail_redirect(message, area_id: @life_area&.id, focus_id: nil)
    redirect_to strategy_redirect_path(area_id: area_id, focus_id: focus_id, peek: 1),
                alert: message, status: :see_other
  end

  def prepare_world_for!(node, focus_id:)
    prepare_world_for_area!(node.life_area_id, focus_id: focus_id)
  end

  def prepare_world_for_area!(area_id, focus_id:)
    @journey = current_user.life_journeys.active.find_by(life_area_id: area_id) ||
               current_user.primary_focused_journey
    return if @journey.blank?

    @goals = current_user.strategy_goals.for_area(area_id).ordered.includes(:parent, children: { children: :children })
    @goal = @goals.for_kind("goal").roots.first
    @focus = focus_id.present? ? @goals.find { |g| g.id == focus_id.to_i } : @goal
    @focus ||= @goal
    if @focus&.month? || @focus&.week?
      @focus = @focus.ancestor_chain.reverse.find { |n| n.project? || n.plan? || n.goal? } || @goal
    end
    @branch_plan, @branch_project = branch_for(@focus)
    @today_battles = today_battles_for(@focus || @goal)
    @today_battle = @today_battles.find { |b| b.completed_at.blank? } || @today_battles.first
    @mountain = Strategy::Mountain.for(goal: @goal)
    Climb::Streak.reconcile!(user: current_user)
    @climb_streak = Climb::Streak.status(user: current_user)
    @mountain_ready = Strategy::HierarchyReady.call(user: current_user, goal: @goal)
    @next_up = nil
    @sheet_node = @created || @updated || @focus
    @open_peek = false
    @open_sheet = false
    @force_notebook = @created&.plan? || @created&.goal?
    @upcoming_battle = Strategy::UpcomingBattle.for(user: current_user, journey: @journey)
    @notebook_guide =
      if @goal.blank?
        nil
      elsif @goal.children.select(&:plan?).empty?
        :add_first_plan
      elsif !@mountain_ready
        :keep_building
      elsif @upcoming_battle.present?
        :tomorrow
      else
        :fight_today
      end
  end

  def branch_for(focus)
    plan =
      if focus&.plan?
        focus
      elsif focus&.project?
        focus.parent
      elsif focus&.day?
        focus.parent&.parent
      end
    project =
      if focus&.project?
        focus
      elsif focus&.day?
        focus.parent
      end
    [ plan, project ]
  end

  def today_battles_for(focus)
    return [] if @goal.blank?

    root =
      if focus&.day? then focus.parent
      elsif focus&.project? then focus
      elsif focus&.plan? then focus
      else @goal
      end
    return [] if root.blank?

    Strategy::Progress.battles_under(root).select { |b| b.scheduled_on == Date.current }
  end
end
