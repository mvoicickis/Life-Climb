# frozen_string_literal: true

module Focus
  class SetJourneys
    class Error < StandardError; end

    def self.call(user:, journey_ids:)
      new(user:, journey_ids:).call
    end

    def initialize(user:, journey_ids:)
      @user = user
      @journey_ids = Array(journey_ids).map(&:to_i).reject(&:zero?).uniq
    end

    def call
      raise Error, "Pick at least one journey to focus on" if @journey_ids.empty?
      raise Error, "Focus on at most 3 journeys" if @journey_ids.size > 3

      journeys = @user.life_journeys.where(id: @journey_ids).to_a
      raise Error, "Those journeys are not available" if journeys.size != @journey_ids.size

      ordered = @journey_ids.map { |id| journeys.find { |j| j.id == id } }

      ActiveRecord::Base.transaction do
        @user.life_journeys.where.not(focus_position: nil).update_all(focus_position: nil)

        ordered.each_with_index do |journey, index|
          journey.update!(focus_position: index + 1, status: "active")
        end
      end

      @user.life_journeys.focused.reload
    end
  end
end
