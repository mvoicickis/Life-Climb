# frozen_string_literal: true

# Queues a sharper tomorrow battle under an open Strategy project after "Not yet".
class BattleAnglesController < ApplicationController
  def create
    project = current_user.strategy_goals.find(params[:project_id])
    unless project.project? && project.completed_at.blank?
      redirect_to dashboard_path, alert: t("dash.battle_angles.invalid") and return
    end

    title = params.require(:title).to_s.strip
    unless Strategy::BattleAngles.valid_title?(project: project, title: title)
      redirect_to dashboard_path, alert: t("dash.battle_angles.invalid_angle") and return
    end

    parent = practice_parent_for(project)
    tomorrow = Date.current + 1.day
    battle = current_user.strategy_goals.new(
      life_area: project.life_area,
      life_journey_id: project.life_journey_id,
      parent: parent,
      horizon: "day",
      title: title,
      scheduled_on: tomorrow,
      position: next_position(parent)
    )

    if battle.save
      Strategy::Celebrate.call(user: current_user, goal: battle)
      Strategy::CascadeToDaily.call(user: current_user, life_area: project.life_area)
      Strategy::BattleAngleQueue.clear(session: session)
      redirect_to dashboard_path, notice: t("dash.battle_angles.queued", title: title)
    else
      redirect_to dashboard_path, alert: battle.errors.full_messages.to_sentence
    end
  end

  private

  # New days hang under nested camps. Path-level camps get (or reuse) a Steps leaf.
  def practice_parent_for(project)
    return project if project.parent&.project?

    leaf = project.children.detect { |child| child.project? && child.leaf_checkpoint? }
    return leaf if leaf

    position = project.children.maximum(:position).to_i
    project.children.create!(
      user: current_user,
      life_area: project.life_area,
      life_journey_id: project.life_journey_id,
      horizon: "project",
      title: I18n.t("strategy.first_climb.nested_camp_title"),
      position: position
    )
  end

  def next_position(parent)
    current_user.strategy_goals.where(parent_id: parent.id, horizon: "day").maximum(:position).to_i + 1
  end
end
