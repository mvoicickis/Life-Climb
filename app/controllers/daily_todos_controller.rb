# frozen_string_literal: true

class DailyTodosController < ApplicationController
  include Dashboard::TodaySurface

  # Freeform battles are planned on Strategy and synced to Today.
  # Today completes / undoes / removes / sets times on already-fed battles.
  def create
    journey = current_user.primary_focused_journey
    redirect_to(
      (journey ? life_journey_path(journey) : dashboard_path),
      alert: t("dash.battle_plan_on_strategy")
    )
  end

  def update
    todo = current_user.daily_todos.find(params[:id])
    if todo.update(todo_time_params)
      redirect_to dashboard_path, notice: t("dash.timeline.time_saved"), status: :see_other
    else
      redirect_to dashboard_path,
                  alert: todo.errors.full_messages.to_sentence.presence || t("dash.timeline.time_save_failed"),
                  status: :see_other
    end
  end

  def complete
    todo = current_user.daily_todos.find(params[:id])
    @todo = todo
    @uncompleted = false

    if todo.completed?
      Battles::UncompleteTodo.call(todo: todo, user: current_user)
      @uncompleted = true
    else
      day = todo.strategy_goal
      if day&.practice_tasks&.incomplete&.exists?
        redirect_to dashboard_path, alert: t("dash.checklist_finish_objectives"), status: :see_other
        return
      end

      checklist = day&.practice_tasks&.any?
      project = checklist ? nil : day&.quantified_path_project
      if project && !valid_quantity_amount?(params[:amount])
        redirect_to dashboard_path,
                    alert: t("strategy.quantity.amount_required", unit: project.unit),
                    status: :see_other
        return
      end

      begin
        result = Battles::CompleteTodo.call(
          todo: todo,
          user: current_user,
          session: session,
          amount: params[:amount]
        )
      rescue ArgumentError
        redirect_to dashboard_path, alert: t("dash.checklist_finish_objectives"), status: :see_other
        return
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error(
          "[DailyTodosController#complete] #{e.class}: #{e.message} " \
          "(record=#{e.record.class.name}##{e.record&.id})"
        )
        redirect_to dashboard_path,
                    alert: e.record.errors.full_messages.to_sentence.presence || t("dash.timeline.time_save_failed"),
                    status: :see_other
        return
      end

      @result = result
      flash[:ap_gained] = result.awarded
      flash[:battle_celebrate] = true
      maybe_milestone_climb_reward!(
        awarded: result.awarded,
        streak: result.streak,
        personal_best: result.personal_best_new
      )
    end
    Journeys::SyncClimbFromToday.call(user: current_user)

    respond_to do |format|
      format.turbo_stream do
        assign_today_complete_stream!
        discard_complete_flashes!
        render :complete, status: :ok
      end
      format.html do
        redirect_to dashboard_path, status: :see_other
      end
    end
  end

  def destroy
    todo = current_user.daily_todos.find(params[:id])
    todo.destroy!
    Journeys::SyncClimbFromToday.call(user: current_user)
    redirect_to dashboard_path
  end

  # Today entry for checklist steps when the battle has no strategy_goal yet.
  def create_step
    todo = current_user.daily_todos.find(params[:id])
    title = params.require(:title).to_s.strip
    if title.blank?
      redirect_to dashboard_path, alert: t("dash.add_step.need_title"), status: :see_other
      return
    end

    day = nil
    ActiveRecord::Base.transaction do
      day = Strategy::EnsureDayForTodo.call(todo: todo)
      position = (day.practice_tasks.maximum(:position) || -1) + 1
      day.practice_tasks.create!(
        user: current_user,
        title: title,
        position: position
      )
    end

    Strategy::CascadeToDaily.call(user: current_user, life_area: day.life_area)
    redirect_to dashboard_path, status: :see_other
  rescue Strategy::EnsureDayForTodo::Error => e
    redirect_to dashboard_path, alert: e.message, status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dashboard_path,
                alert: e.record.errors.full_messages.to_sentence.presence || t("strategy.rpg.objective_add_failed"),
                status: :see_other
  end

  private

  def assign_today_complete_stream!
    @journey = current_user.primary_focused_journey
    assign_today_battle_surface!(reconcile: false)
    @battlefield_health = Today::BattlefieldHealth.call(
      open_count: @battle_open_count,
      total_count: @battle_total_count
    )
    @battlefield_day_ended = Today::BattlefieldDay.ended?(session)
    @climb_streak = Climb::Streak.status(user: current_user)
    @recap_share = t(
      "dash.battlefield.share_text",
      title: @battlefield_health.result_title,
      done: @battlefield_health.done_count,
      total: @battlefield_health.total_count,
      hp: @battlefield_health.hp
    )

    if @uncompleted
      @stream_ap_gained = 0
      @stream_celebrate = false
      @stream_boss = false
      @stream_climb_reward = nil
    else
      @stream_ap_gained = @result.awarded.to_i
      @stream_celebrate = true
      @stream_boss = flash[:climb_boss].present?
      @stream_climb_reward = flash[:climb_reward]
    end
  end

  def discard_complete_flashes!
    flash.discard(:ap_gained)
    flash.discard(:battle_celebrate)
    flash.discard(:climb_boss)
    flash.discard(:climb_reward)
  end

  def todo_time_params
    params.require(:daily_todo).permit(:start_time, :end_time)
  end

  def valid_quantity_amount?(raw)
    return false if raw.blank?

    BigDecimal(raw.to_s).positive?
  rescue ArgumentError
    false
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
end
