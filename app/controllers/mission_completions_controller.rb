# frozen_string_literal: true

class MissionCompletionsController < ApplicationController
  def create
    mission = current_user.missions.find(params[:mission_id])
    aspect = params[:aspect_key].to_s
    if aspect.present? && LifeArea::CATALOG_KEYS.include?(aspect)
      mission.update!(aspect_key: aspect)
    end

    Missions::Complete.call(user: current_user, mission: mission)

    streak = Climb::Streak.touch!(user: current_user)
    pb = Climb::PersonalBest.record!(user: current_user, awarded: mission.lp_reward.to_i)
    Journeys::SyncClimbFromToday.call(user: current_user)

    # Same light juice as todo checkboxes — modal only for rare milestones.
    flash[:ap_gained] = mission.lp_reward.to_i
    flash[:battle_celebrate] = true
    if pb.new_record || streak.earned_freeze
      flash[:climb_boss] = true
      journey = current_user.primary_focused_journey
      goal = journey && Goals::Current.goal_for(user: current_user, journey: journey)
      flash[:climb_reward] = Climb::Reward.for_battle(
        user: current_user,
        awarded: mission.lp_reward.to_i,
        goal: goal,
        streak_days: streak.days,
        personal_best: pb.new_record,
        earned_freeze: streak.earned_freeze,
        boss: true
      )
    end

    redirect_to dashboard_path
  rescue Missions::Complete::Error => e
    redirect_to dashboard_path, alert: e.message
  end
end
