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
      repeat: parse_repeat(kind),
      position: next_position(parent, kind)
    )
    apply_quantity_params!(goal) if kind == "project" && parent&.plan?
    apply_color_key_params!(goal) if kind == "project"

    if goal.save
      celebration = Strategy::Celebrate.call(user: current_user, goal: goal)
      Strategy::CascadeToDaily.call(user: current_user, life_area: @life_area) if goal.day?
      Strategy::SyncCompletion.resync!(node: goal) if goal.plan? || goal.project?
      if celebration[:amount].to_i.positive?
        flash[:sp_gained] = celebration[:amount]
        flash[:climb_boss] = true if celebration[:amount].to_i >= 50
      end

      # Always redirect — Turbo form posts used to hit a no-op turbo_stream that
      # saved the record but left the Quest Folders sheet unchanged.
      redirect_to strategy_redirect_path(**create_redirect_params(goal)),
                  notice: create_notice(goal, celebration),
                  status: :see_other
    else
      fail_redirect(goal.errors.full_messages.to_sentence, focus_id: parent&.id)
    end
  end

  def destroy
    goal = current_user.strategy_goals.find(params[:id])
    area_id = goal.life_area_id
    parent_id = goal.parent_id
    parent = goal.parent
    removed_id = goal.id
    was_plan = goal.plan?
    was_project = goal.project?
    root_id = goal.root_goal&.id
    plan_for_project =
      if was_project
        goal.parent&.plan? ? goal.parent : goal.ancestor_chain.reverse.find(&:plan?)
      end
    next_plan_id = was_plan ? next_sibling_plan_id(goal) : nil
    next_focus_id = was_project ? next_sibling_project_id(goal) : nil
    goal.destroy!
    Strategy::SyncCompletion.resync!(node: parent) if was_plan || was_project
    prepare_world_for_area!(area_id, focus_id: next_focus_id || parent_id)
    @removed_id = removed_id
    respond_to do |format|
      format.turbo_stream { render :destroy }
      format.html do
        redirect_to after_destroy_path(
                      area_id: area_id,
                      parent_id: parent_id,
                      was_plan: was_plan,
                      was_project: was_project,
                      next_plan_id: next_plan_id,
                      next_focus_id: next_focus_id,
                      plan_id: plan_for_project&.id,
                      goal_id: root_id
                    ),
                    notice: t("strategy.removed"), status: :see_other
      end
    end
  end

  def update
    goal = current_user.strategy_goals.find(params[:id])
    schedule_only = goal.day? && params.key?(:scheduled_on) && !params.key?(:title)

    if params.key?(:title)
      goal.title = params[:title].to_s.strip
    end

    quantity_touched = goal.path_level_camp? && params.key?(:track_quantity)
    apply_quantity_params!(goal) if goal.path_level_camp?
    apply_color_key_params!(goal) if goal.project?

    if goal.day? && params.key?(:scheduled_on)
      goal.scheduled_on = parse_day_schedule_param(params[:scheduled_on])
    end

    # Stay inside the Practice Category after toggling today's practice.
    focus_id = if goal.day?
      goal.parent_id
    elsif goal.goal?
      goal.id
    else
      goal.parent_id
    end

    if goal.save
      Strategy::CascadeToDaily.call(user: current_user, life_area: goal.life_area) if goal.day?
      Strategy::SyncCompletion.resync!(node: goal) if quantity_touched
      @updated = goal
      prepare_world_for!(goal, focus_id: focus_id)
      respond_to do |format|
        # Schedule toggles always reload Mountain so Practice Category state stays in sync.
        if schedule_only
          format.any { redirect_to after_update_path(goal), status: :see_other }
        else
          format.turbo_stream { render :update }
          format.html do
            redirect_to after_update_path(goal), notice: t("strategy.renamed"), status: :see_other
          end
        end
      end
    else
      fail_redirect(goal.errors.full_messages.to_sentence, area_id: goal.life_area_id, focus_id: focus_id)
    end
  end

  private

  def after_destroy_path(area_id:, parent_id:, was_plan: false, was_project: false, next_plan_id: nil, next_focus_id: nil, plan_id: nil, goal_id: nil)
    journey = current_user.life_journeys.active.find_by(life_area_id: area_id) ||
              current_user.primary_focused_journey
    return new_life_journey_path(life_area_id: area_id) if journey.blank?

    if was_plan
      return life_journey_path(journey, goal_id: parent_id, plan_id: next_plan_id)
    end

    if was_project
      return life_journey_path(
        journey,
        goal_id: goal_id,
        plan_id: plan_id || parent_id,
        focus_id: next_focus_id || plan_id || parent_id
      )
    end

    strategy_redirect_path(area_id: area_id, focus_id: parent_id)
  end

  # Prefer the next sibling plan; otherwise the previous one. Nil when none remain.
  def next_sibling_plan_id(plan)
    parent = plan.parent
    return if parent.blank?

    siblings = parent.children.select(&:plan?).sort_by { |p| [ p.position.to_i, p.id ] }
    index = siblings.index { |p| p.id == plan.id }
    return if index.nil?

    remaining = siblings.reject { |p| p.id == plan.id }
    return if remaining.empty?

    remaining[index] || remaining[index - 1] || remaining.first
  end

  # Prefer the next sibling camp; otherwise the previous one.
  def next_sibling_project_id(project)
    parent = project.parent
    return if parent.blank?

    siblings = parent.children.select(&:project?).sort_by { |p| [ p.position.to_i, p.id ] }
    index = siblings.index { |p| p.id == project.id }
    return if index.nil?

    (siblings[index + 1] || (index.positive? ? siblings[index - 1] : nil))&.id
  end

  def after_update_path(goal)
    journey = current_user.life_journeys.active.find_by(life_area_id: goal.life_area_id) ||
              current_user.primary_focused_journey
    return new_life_journey_path(life_area_id: goal.life_area_id) if journey.blank?

    # Keep Mountain focused on the renamed node so the new title is obvious.
    if goal.goal?
      return life_journey_path(journey, goal_id: goal.id)
    end

    if goal.plan?
      return life_journey_path(journey, goal_id: goal.parent_id, plan_id: goal.id)
    end

    if goal.day?
      category = goal.parent
      plan = category&.parent if category&.parent&.plan?
      plan ||= category&.ancestor_chain&.reverse&.find(&:plan?)
      root = goal.root_goal
      return life_journey_path(
        journey,
        goal_id: root&.id,
        plan_id: plan&.id,
        focus_id: category&.id
      )
    end

    if goal.project?
      plan = goal.parent&.plan? ? goal.parent : goal.ancestor_chain.reverse.find(&:plan?)
      return life_journey_path(
        journey,
        goal_id: goal.root_goal&.id,
        plan_id: plan&.id,
        focus_id: goal.id
      )
    end

    strategy_redirect_path(area_id: goal.life_area_id, focus_id: goal.parent_id)
  end

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

  # Path-level project quantity targets. Only applied when the form includes
  # track_quantity (section create/edit). Never touches current_amount.
  def apply_quantity_params!(goal)
    return unless params.key?(:track_quantity)

    if ActiveModel::Type::Boolean.new.cast(params[:track_quantity])
      goal.target_amount = params[:target_amount].presence
      goal.unit = params[:unit].to_s.strip.presence
    else
      goal.target_amount = nil
      goal.unit = nil
    end
  end

  # Leaf-quest accent. Only applied when the form includes color_key.
  def apply_color_key_params!(goal)
    return unless params.key?(:color_key)

    goal.color_key = params[:color_key].to_s.strip.presence
  end

  def parse_due_on(kind, parent)
    case kind
    when "goal"
      raw = params[:due_on].presence
      raw ? Date.parse(raw.to_s) : Strategy::YearCycle.default_goal_due
    when "plan", "project"
      raw = params[:due_on].presence
      raw ? Date.parse(raw.to_s) : parent&.due_on
    end
  rescue ArgumentError, TypeError
    kind == "goal" ? Strategy::YearCycle.default_goal_due : parent&.due_on
  end

  def parse_scheduled_on(kind)
    return unless kind == "day"

    Date.parse(params[:scheduled_on].presence || Date.current.to_s)
  rescue ArgumentError, TypeError
    Date.current
  end

  def parse_repeat(kind)
    return "none" unless kind == "day"

    value = params[:repeat].to_s
    StrategyGoal::REPEAT_KINDS.include?(value) ? value : "none"
  end

  # Day goals require a date — "later" / blank moves practice off today (tomorrow).
  def parse_day_schedule_param(raw)
    value = raw.to_s.strip
    return Date.current + 1.day if value.blank? || value == "later"

    Date.parse(value)
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
    when "project" then goal.id # Keep Mountain on the camp just created
    when "day" then goal.parent_id # Stay inside the Practice Category
    else goal.parent_id
    end
  end

  # Keep Destination + Path context after create so the new node is visible.
  def create_redirect_params(goal)
    case goal.kind
    when "goal"
      { focus_id: goal.id, goal_id: goal.id }
    when "plan"
      { focus_id: goal.id, goal_id: goal.parent_id, plan_id: goal.id }
    when "project"
      plan = goal.parent&.plan? ? goal.parent : goal.ancestor_chain.reverse.find(&:plan?)
      {
        focus_id: goal.id,
        goal_id: goal.root_goal&.id,
        plan_id: plan&.id
      }
    when "day"
      category = goal.parent
      plan = category&.parent if category&.parent&.plan?
      plan ||= category&.ancestor_chain&.reverse&.find(&:plan?)
      {
        focus_id: category&.id,
        goal_id: goal.root_goal&.id,
        plan_id: plan&.id
      }
    else
      { focus_id: redirect_focus_id(goal) }
    end
  end

  def create_notice(goal, celebration)
    return celebration[:notice] if celebration[:notice].present?

    if goal.project?
      I18n.t("strategy.rpg.checkpoint_added", title: goal.title)
    end
  end

  def strategy_redirect_path(area_id: @life_area&.id, focus_id: nil, goal_id: nil, peek: nil, sheet: nil, plan_id: nil)
    area_id ||= current_user.primary_focused_journey&.life_area_id
    journey = current_user.life_journeys.active.find_by(life_area_id: area_id) ||
              current_user.primary_focused_journey
    if journey
      life_journey_path(
        journey,
        focus_id: focus_id,
        goal_id: goal_id,
        plan_id: plan_id,
        peek: peek,
        sheet: sheet
      )
    else
      new_life_journey_path(life_area_id: area_id)
    end
  end

  def fail_redirect(message, area_id: @life_area&.id, focus_id: nil, goal_id: nil)
    redirect_to strategy_redirect_path(area_id: area_id, focus_id: focus_id, goal_id: goal_id, peek: 1),
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
