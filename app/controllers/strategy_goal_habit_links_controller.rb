# frozen_string_literal: true

class StrategyGoalHabitLinksController < ApplicationController
  def create
    project = current_user.strategy_goals.find(params[:strategy_goal_id])
    unless project.path_level_camp? && !project.holding?
      return redirect_to project_trackers_path(project),
                         alert: t("strategy.rpg.project_trackers.need_project"),
                         status: :see_other
    end

    habit =
      if params[:habit_id].present?
        link_existing!(project)
      else
        create_and_link!(project)
      end

    redirect_to project_trackers_path(project),
                notice: t("strategy.rpg.project_trackers.linked", name: habit.name),
                status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to project_trackers_path(project),
                alert: e.record.errors.full_messages.to_sentence.presence || e.message,
                status: :see_other
  rescue ActiveRecord::RecordNotFound
    redirect_to life_points_path, alert: t("strategy.rpg.project_trackers.habit_missing"), status: :see_other
  end

  private

  def link_existing!(project)
    habit = current_user.habits.find(params[:habit_id])
    HabitProjectLink.find_or_create_by!(habit: habit, strategy_goal: project)
    habit
  end

  def create_and_link!(project)
    unit = params[:unit].presence || "times"
    habit = current_user.habits.create!(
      name: params[:name].to_s.strip,
      unit: unit,
      points: 5,
      frequency: "daily",
      active: true,
      show_on_home: true,
      stat_type: "growth",
      life_journey: project.life_journey,
      quantity_checkin: Habit.infer_quantity_checkin?(stat_type: "growth", goal: nil, unit: unit)
    )
    HabitProjectLink.create!(habit: habit, strategy_goal: project)
    habit
  end

  def project_trackers_path(project)
    journey = project.life_journey || current_user.primary_focused_journey
    if journey
      life_journey_path(journey, focus_id: project.id, sheet: "trackers")
    else
      life_points_path
    end
  end
end
