# frozen_string_literal: true

module Journeys
  class Create
    class Error < StandardError; end

    DEFAULT_GAP = 70.0

    def self.call(user:, life_area:, title:, ideal_scene:, current_reality:, next_win: nil, closer_percent: nil)
      new(
        user:,
        life_area:,
        title:,
        ideal_scene:,
        current_reality:,
        next_win:,
        closer_percent:
      ).call
    end

    def initialize(user:, life_area:, title:, ideal_scene:, current_reality:, next_win:, closer_percent:)
      @user = user
      @life_area = life_area
      @title = title.to_s.strip
      @ideal_scene = ideal_scene.to_s.strip
      @current_reality = current_reality.to_s.strip
      @next_win = next_win.to_s.strip
      @closer_percent = closer_percent
    end

    def call
      raise Error, "Choose a life area first" unless @life_area
      raise Error, "This area is not yours" unless @life_area.user_id == @user.id
      raise Error, "Name what you want to achieve" if @title.blank? && @ideal_scene.blank?
      raise Error, "Describe what success looks like" if @ideal_scene.blank?
      raise Error, "Describe where you are today" if @current_reality.blank?

      title = @title.presence || @ideal_scene.truncate(80)
      gap = baseline_gap

      ActiveRecord::Base.transaction do
        journey = @user.life_journeys.create!(
          life_area: @life_area,
          title: title,
          ideal_scene: @ideal_scene,
          current_reality: @current_reality,
          next_win: @next_win.presence,
          milestones: (@next_win.present? ? [ { "title" => @next_win, "tags" => [] } ] : []),
          status: "active",
          gap_percent: gap,
          activated_at: Time.current,
          scenes_revised_at: Time.current
        )

        journey.gap_snapshots.create!(recorded_on: Date.current, gap_percent: gap)
        journey
      end
    end

    private

    def baseline_gap
      return DEFAULT_GAP if @closer_percent.nil? || @closer_percent.to_s.strip.blank?

      closer = @closer_percent.to_f.clamp(0, 100)
      (100.0 - closer).round(2)
    end
  end
end
