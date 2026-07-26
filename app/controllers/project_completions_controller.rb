# frozen_string_literal: true

# Marks a Strategy project done (or leads into next-battle angles) after a battle win.
class ProjectCompletionsController < ApplicationController
  def create
    project = current_user.strategy_goals.find(params[:project_id])
    unless project.project?
      redirect_to dashboard_path, alert: t("dash.project_check.invalid") and return
    end

    Strategy::ProjectCheckQueue.dequeue(session: session, project_id: project.id)

    if params[:decision].to_s == "done"
      before = root_progress(project)
      ActiveRecord::Base.transaction do
        project.complete!
        Strategy::SyncCompletion.call(project: project)
      end
      after = root_progress(project)
      Strategy::BattleAngleQueue.clear(session: session)
      flash[:battle_celebrate] = true if after > before
      redirect_to dashboard_path, notice: t("dash.project_check.done_notice", title: project.title, percent: after)
    else
      Strategy::BattleAngleQueue.enqueue(session: session, project_id: project.id)
      redirect_to dashboard_path, notice: t("dash.project_check.not_yet_notice")
    end
  end

  private

  def root_progress(project)
    goal = project.reload.root_goal
    return 0 unless goal

    Strategy::Progress.percent(goal.reload)
  end
end
