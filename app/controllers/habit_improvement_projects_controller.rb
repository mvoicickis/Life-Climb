# frozen_string_literal: true

class HabitImprovementProjectsController < ApplicationController
  def create
    habit = current_user.habits.find(params[:habit_id])
    project = Trackers::CreateImprovementProject.call(user: current_user, habit: habit)
    journey = project.life_journey
    redirect_to life_journey_path(journey, focus_id: project.id),
                notice: t("areas.improve.created", title: project.title),
                status: :see_other
  rescue Trackers::CreateImprovementProject::Error => e
    redirect_to habit_path(params[:habit_id]), alert: e.message, status: :see_other
  end
end
