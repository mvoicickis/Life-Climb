# frozen_string_literal: true

class MountainTourEventsController < ApplicationController
  EVENTS = {
    "viewed" => "mountain_tour_step_viewed",
    "completed" => "mountain_tour_step_completed"
  }.freeze

  def create
    step = params[:step].to_s
    event = params[:event].to_s
    return head :unprocessable_entity unless OnboardingMountainTour::STEPS.include?(step)
    return head :unprocessable_entity unless EVENTS.key?(event)

    Analytics::Track.call(
      user: current_user,
      name: EVENTS.fetch(event),
      properties: { step: step }
    )
    head :no_content
  end
end
