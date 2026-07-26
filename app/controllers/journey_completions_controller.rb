class JourneyCompletionsController < ApplicationController
  def create
    journey = current_user.life_journeys.find(params[:life_journey_id])
    Journeys::Complete.call(user: current_user, journey: journey)
    redirect_to next_mountain_path, notice: t("journeys.completed_notice", title: journey.title, lp: Journeys::Complete::COMPLETION_LP)
  rescue Journeys::Complete::Error => e
    redirect_to life_journey_path(params[:life_journey_id]), alert: e.message
  end
end
