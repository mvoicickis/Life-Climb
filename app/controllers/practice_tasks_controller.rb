# frozen_string_literal: true

# Objectives inside a Quest Folder checklist on Mountain (plan) / Today (complete).
class PracticeTasksController < ApplicationController
  before_action :require_planning_v2

  def create
    practice = current_user.strategy_goals.battles.find(params[:strategy_goal_id])
    title = params.require(:title).to_s.strip
    explicit_position = params[:position].present?
    task = nil

    PracticeTask.transaction do
      position = parse_position(params[:position], practice)
      shift_siblings_from!(practice, position) if explicit_position
      task = practice.practice_tasks.new(
        user: current_user,
        title: title,
        position: position,
        track_quantity: track_quantity_param_for(practice)
      )
      task.save!
      task.complete! if ActiveModel::Type::Boolean.new.cast(params[:completed])
    end

    Strategy::CascadeToDaily.call(user: current_user, life_area: practice.life_area)
    assign_quest_stream!(practice)
    respond_to do |format|
      format.turbo_stream { render :create }
      format.html { redirect_to after_create_path(practice), status: :see_other }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to after_create_path(practice),
                alert: e.record.errors.full_messages.to_sentence.presence || t("strategy.rpg.objective_add_failed"),
                status: :see_other
  end

  def update
    task = current_user.practice_tasks.find(params[:id])
    practice = task.strategy_goal

    if params.key?(:completed)
      completing = ActiveModel::Type::Boolean.new.cast(params[:completed])
      if completing
        unless complete_objective!(task, practice)
          return
        end
      else
        Strategy::Quantity::Unlog.call(practice_task: task)
        task.reopen!
        reopen_checklist_day_if_needed!(practice)
      end
      Journeys::SyncClimbFromToday.call(user: current_user)
      respond_today_quest_completion!(practice)
    elsif params.key?(:title) || params.key?(:track_quantity)
      attrs = {}
      attrs[:title] = params.require(:title).to_s.strip if params.key?(:title)
      attrs[:track_quantity] = track_quantity_param_for(practice) if params.key?(:track_quantity)
      task.update!(attrs)
      assign_quest_stream!(practice)
      respond_to do |format|
        format.turbo_stream { render :update }
        format.html { redirect_to mountain_focus_path(practice), status: :see_other }
      end
    else
      redirect_to dashboard_path, status: :see_other
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to(
      (params.key?(:completed) ? dashboard_path : mountain_focus_path(e.record.strategy_goal)),
      alert: e.record.errors.full_messages.to_sentence,
      status: :see_other
    )
  end

  def destroy
    task = current_user.practice_tasks.find(params[:id])
    practice = task.strategy_goal
    task.destroy!
    Strategy::CascadeToDaily.call(user: current_user, life_area: practice.life_area)
    assign_quest_stream!(practice)
    respond_to do |format|
      format.turbo_stream { render :destroy }
      format.html { redirect_to mountain_focus_path(practice), status: :see_other }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("dash.battle_angles.invalid"), status: :see_other
  end

  private

  def assign_quest_stream!(practice)
    @practice = practice
    @folder = practice.parent
    @tasks = practice.practice_tasks.ordered.to_a
    @create_url = strategy_goal_practice_tasks_path(practice)
    @qty_project = practice.quantified_path_project
  end

  # Sheet ticks use Turbo Stream so the dialog stays open; compact-row ticks redirect.
  # When the last step auto-finishes the battle, fall back to a full redirect so
  # celebrate / AP flash still run on a fresh Today paint.
  def respond_today_quest_completion!(practice)
    todo = linked_today_todo(practice)
    want_stream = params[:respond_with].to_s == "today_quest_stream"

    if want_stream && request.format.turbo_stream? && todo.present? && !todo.completed?
      assign_today_quest_stream!(practice, todo)
      render :complete_today
    else
      redirect_to dashboard_path, status: :see_other
    end
  end

  def assign_today_quest_stream!(practice, todo)
    @todo = todo
    @day = practice
    @tasks = practice.practice_tasks.ordered.to_a
    @shell_ready = @tasks.all?(&:completed?)
  end

  def complete_objective!(task, practice)
    project = practice.quantified_path_project
    if task.tracks_quantity?
      unless valid_quantity_amount?(params[:amount])
        redirect_to dashboard_path,
                    alert: t("strategy.quantity.amount_required", unit: project&.unit),
                    status: :see_other
        return false
      end

      Strategy::Quantity::Log.call(
        project: project,
        amount: params[:amount],
        user: current_user,
        source_day: practice,
        daily_todo: linked_today_todo(practice),
        practice_task: task
      )
    end

    task.complete!
    finish_checklist_day_if_ready!(practice)
    true
  end

  def finish_checklist_day_if_ready!(practice)
    return unless practice.all_objectives_complete?

    Strategy::CascadeToDaily.call(user: current_user, life_area: practice.life_area)
    todo = linked_today_todo(practice)
    return if todo.blank? || todo.completed?

    # Checklist quantity (if any) already logged on opted-in objectives — no second prompt.
    result = Battles::CompleteTodo.call(todo: todo, user: current_user, session: session)
    flash[:ap_gained] = todo.lp_reward.to_i
    flash[:battle_celebrate] = true
    maybe_milestone_climb_reward!(
      awarded: todo.lp_reward.to_i,
      streak: result.streak,
      personal_best: result.personal_best_new
    )
  end

  def reopen_checklist_day_if_needed!(practice)
    todo = linked_today_todo(practice)
    return if todo.blank? || !todo.completed?

    Battles::UncompleteTodo.call(todo: todo, user: current_user, reset_objectives: false)
  end

  def track_quantity_param_for(practice)
    return false if practice.quantified_path_project.blank?

    ActiveModel::Type::Boolean.new.cast(params[:track_quantity])
  end

  def valid_quantity_amount?(raw)
    return false if raw.blank?

    BigDecimal(raw.to_s).positive?
  rescue ArgumentError
    false
  end

  def linked_today_todo(practice)
    current_user.daily_todos.for_day(Date.current).find_by(strategy_goal_id: practice.id)
  end

  def parse_position(raw, practice)
    return next_position(practice) if raw.blank?

    value = Integer(raw)
    value.negative? ? 0 : value
  rescue ArgumentError, TypeError
    next_position(practice)
  end

  def next_position(practice)
    (practice.practice_tasks.maximum(:position) || -1) + 1
  end

  def shift_siblings_from!(practice, position)
    practice.practice_tasks.where("position >= ?", position).update_all("position = position + 1")
  end

  def return_to_today?
    params[:return_to].to_s == "today"
  end

  def after_create_path(practice)
    return_to_today? ? dashboard_path : mountain_focus_path(practice)
  end

  def mountain_focus_path(practice)
    camp = practice.parent
    plan = camp&.parent&.plan? ? camp.parent : camp&.ancestor_chain&.reverse&.find(&:plan?)
    goal = plan&.parent || camp&.root_goal
    journey = practice.life_journey ||
              current_user.life_journeys.active.find_by(life_area_id: practice.life_area_id) ||
              current_user.primary_focused_journey

    return dashboard_path if journey.blank?

    life_journey_path(
      journey,
      goal_id: goal&.id,
      plan_id: plan&.id,
      focus_id: camp&.id
    )
  end

  def maybe_milestone_climb_reward!(awarded:, streak:, personal_best:)
    milestone = personal_best || streak.earned_freeze
    return unless milestone

    flash[:climb_boss] = true
    journey = current_user.primary_focused_journey
    goal = journey && current_user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
    flash[:climb_reward] = Climb::Reward.for_battle(
      user: current_user,
      awarded: awarded,
      goal: goal,
      streak_days: streak.days,
      personal_best: personal_best,
      earned_freeze: streak.earned_freeze,
      boss: true
    )
  end

  def require_planning_v2
    return if current_user.planning_v2?

    redirect_to life_area_selections_path
  end
end
