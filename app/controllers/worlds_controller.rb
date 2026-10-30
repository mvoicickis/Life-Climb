# frozen_string_literal: true

class WorldsController < ApplicationController
  def show
    journeys = current_user.life_journeys.active.includes(:life_area).order(:id).to_a
    grouped = journeys.group_by { |journey| journey.life_area.world_ring }
    @wins_by_journey = Battles::WinsByJourney.call(user: current_user)
    @focused_journey = journeys.find { |journey| journey.focus_position == 1 } ||
                       current_user.primary_focused_journey
    @rings = LifeArea::WORLD_RINGS.map do |ring|
      list = grouped[ring] || []
      {
        key: ring,
        journeys: list,
        color_index: LifeArea.world_ring_color_index(ring),
        live: list.any?,
        creatable: LifeArea.key_for_ring(ring).present?
      }
    end
  end

  def focus
    journey = current_user.life_journeys.active.find(params[:journey_id])
    Focus::SetJourneys.call(user: current_user, journey_ids: [ journey.id ])
    Missions::EnsureDaily.call(user: current_user)
    redirect_to life_journey_path(journey)
  rescue Focus::SetJourneys::Error
    raise ActiveRecord::RecordNotFound
  end
end
