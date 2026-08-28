# frozen_string_literal: true

class OnboardingMountainToursController < ApplicationController
  def update
    current_user.mark_onboarding_mountain_tour_done!
    head :no_content
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end
end
