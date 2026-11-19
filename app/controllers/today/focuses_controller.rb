# frozen_string_literal: true

module Today
  # Switch the focused journey from Today's other-mountains dropdown, then stay on Today.
  class FocusesController < ApplicationController
    def update
      journey = current_user.life_journeys.active.find(params[:journey_id])
      Focus::SetJourneys.call(user: current_user, journey_ids: [ journey.id ])
      Missions::EnsureDaily.call(user: current_user)
      redirect_to dashboard_path
    rescue Focus::SetJourneys::Error
      raise ActiveRecord::RecordNotFound
    end
  end
end
