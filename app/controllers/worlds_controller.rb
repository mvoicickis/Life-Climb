# frozen_string_literal: true

class WorldsController < ApplicationController
  def show
    active = current_user.life_journeys.active.includes(:life_area).order(:id).to_a
    active_by_ring = active.group_by { |journey| journey.life_area.world_ring }

    # One batched read: completed journey ids + area key → ring (keeps wins after finish).
    completed_by_ring = Hash.new { |hash, key| hash[key] = [] }
    current_user.life_journeys.where(status: "completed")
      .joins(:life_area)
      .pluck(:id, "life_areas.key")
      .each do |journey_id, area_key|
        completed_by_ring[LifeArea.world_ring_for(area_key)] << journey_id
      end

    # Two queries covering every journey (active + completed).
    @wins_by_journey = Battles::WinsByJourney.call(user: current_user)
    # Two queries: last 7 local days per journey.
    wins_by_journey_and_day = Battles::WinsByJourneyAndDay.call(user: current_user, days: 7)
    local_today = Battles::WinsOnLocalDate.local_today_for(current_user)
    week_dates = ((local_today - 6)..local_today).to_a

    @focused_journey = active.find { |journey| journey.focus_position == 1 } ||
                       current_user.primary_focused_journey

    @rings = LifeArea::WORLD_RINGS.map do |ring|
      list = active_by_ring[ring] || []
      completed_ids = completed_by_ring[ring]
      journey_ids = list.map(&:id) + completed_ids
      ring_wins = journey_ids.sum { |id| @wins_by_journey[id].to_i }
      has_goal = list.any? || completed_ids.any?
      week_wins = week_dates.map do |date|
        journey_ids.sum { |id| wins_by_journey_and_day.dig(id, date).to_i }
      end
      {
        key: ring,
        journeys: list,
        color_index: LifeArea.world_ring_color_index(ring),
        live: list.any?,
        has_goal: has_goal,
        wins: ring_wins,
        win_step: WorldsHelper.win_step(ring_wins),
        finished: completed_ids.any?,
        creatable: LifeArea.key_for_ring(ring).present?,
        week_dates: week_dates,
        week_wins: week_wins
      }
    end
    @reach_count = @rings.count { |ring| ring[:has_goal] }
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
