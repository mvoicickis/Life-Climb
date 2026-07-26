# frozen_string_literal: true

module Journeys
  # When Home battle has mission/todos, mark Journey's today climb layer done if unlocked.
  class SyncClimbFromToday
    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      journey = @user.primary_focused_journey
      return unless journey

      mission = journey.missions.for_day(Date.current).primary.order(:id).first
      todos = @user.daily_todos.for_day(Date.current).to_a
      has_today = mission&.title.present? || todos.any? { |t| t.title.present? }
      return unless has_today
      return unless journey.layer_unlocked?("today")
      return if journey.layer_complete?("today")

      journey.mark_layer!("today", "done")
      journey
    end
  end
end
