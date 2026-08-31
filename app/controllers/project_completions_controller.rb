# frozen_string_literal: true

# Marks a Strategy project done (or leads into next-battle angles) after a battle win.
class ProjectCompletionsController < ApplicationController
  def create
    project = current_user.strategy_goals.find(params[:project_id])
    unless project.project?
      redirect_to after_project_check_path(project), alert: t("dash.project_check.invalid") and return
    end
    if project.holding?
      redirect_to after_project_check_path(project), alert: t("dash.project_check.invalid") and return
    end

    Strategy::ProjectCheckQueue.dequeue(session: session, project_id: project.id)

    if params[:decision].to_s == "done"
      goal = project.root_goal
      before_mountain = Strategy::Mountain.for(goal: goal)
      before = before_mountain[:progress].to_i
      ActiveRecord::Base.transaction do
        project.complete!
        Strategy::SyncCompletion.call(project: project)
      end
      after_mountain = Strategy::Mountain.for(goal: goal.reload)
      after = after_mountain[:progress].to_i
      Strategy::BattleAngleQueue.clear(session: session)
      reward = Climb::Reward.for_project(
        user: current_user,
        goal: goal,
        percent_before: before,
        percent_after: after,
        stage_before: before_mountain[:stage]
      )
      flash[:battle_celebrate] = true
      flash[:climb_boss] = true if reward[:kind] == "boss"
      flash[:climb_reward] = reward
      redirect_to after_project_check_path(project),
                  notice: t("dash.project_check.done_notice", title: project.title, percent: after)
    else
      Strategy::BattleAngleQueue.enqueue(session: session, project_id: project.id)
      redirect_to after_project_check_path(project), notice: t("dash.project_check.not_yet_notice")
    end
  end

  private

  def mountain_return?
    params[:return_to].to_s == "mountain"
  end

  def after_project_check_path(project)
    return dashboard_path unless mountain_return?

    journey = project.life_journey || current_user.primary_focused_journey
    goal = project.root_goal
    plan = project.parent if project.parent&.plan?
    life_journey_path(
      journey,
      goal_id: params[:goal_id].presence || goal&.id,
      plan_id: params[:plan_id].presence || plan&.id
    )
  end
end
