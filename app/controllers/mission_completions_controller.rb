class MissionCompletionsController < ApplicationController
  def create
    mission = current_user.missions.find(params[:mission_id])
    Missions::Complete.call(user: current_user, mission: mission)
    Missions::EnsureDaily.call(user: current_user) if current_user.planning_v2?
    redirect_to dashboard_path, notice: t("missions.completed_notice",
      lp: mission.lp_reward,
      gap: mission.gap_delta_percent)
  rescue Missions::Complete::Error => e
    redirect_to dashboard_path, alert: e.message
  end
end
