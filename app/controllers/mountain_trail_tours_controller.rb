# frozen_string_literal: true

# Persist Mountain V4 post–FirstClimb tour progress (steps 2–7).
class MountainTrailToursController < ApplicationController
  def update
    ack = params[:ack].to_i.clamp(0, 7)
    current_user.update!(mountain_trail_tour_ack: ack)
    head :no_content
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end
end
