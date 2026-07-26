# frozen_string_literal: true

class MissionCompletionsController < ApplicationController
  def create
    mission = current_user.missions.find(params[:mission_id])
    aspect = params[:aspect_key].to_s
    if aspect.present? && LifeArea::CATALOG_KEYS.include?(aspect)
      mission.update!(aspect_key: aspect)
    end

    Missions::Complete.call(user: current_user, mission: mission)
    Missions::EnsureDaily.call(user: current_user) if current_user.planning_v2?
    redirect_to dashboard_path, notice: t("missions.completed_notice_short", lp: mission.lp_reward)
  rescue Missions::Complete::Error => e
    redirect_to dashboard_path, alert: e.message
  end
end
