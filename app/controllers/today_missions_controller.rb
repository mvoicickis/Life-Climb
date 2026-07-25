# frozen_string_literal: true

# Sets today's one-sitting mission without exposing Focus.
class TodayMissionsController < ApplicationController
  def create
    journey = current_user.primary_focused_journey
    unless journey
      redirect_to(current_user.life_journeys.where(status: "completed").exists? ? next_mountain_path : new_life_journey_path) and return
    end

    title = params[:title].to_s.strip
    if title.blank?
      redirect_to dashboard_path, alert: t("coach.need_today") and return
    end

    Missions::EnsureDaily.call(user: current_user, mission_title: title)
    redirect_to dashboard_path, notice: t("coach.today_set")
  end
end
