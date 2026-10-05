# frozen_string_literal: true

module Stats
  class GoalsReached
    Result = Struct.new(
      :rows,
      :all_finished_path_camps,
      :any_finished_path_camp,
      :any_completed_journey,
      keyword_init: true
    )

    Row = Struct.new(:title, :completed_on, :camps_count, keyword_init: true)

    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
      @time_zone = Battles::WinsOnLocalDate.time_zone_for(@user)
    end

    def call
      all_finished_path_camps = FinishedPathCamps.total_count(user: @user)
      any_finished_path_camp = all_finished_path_camps.positive?

      journeys = @user.life_journeys.where(status: "completed").order(completed_at: :desc).to_a
      rows = build_rows(journeys)

      Result.new(
        rows: rows,
        all_finished_path_camps: all_finished_path_camps,
        any_finished_path_camp: any_finished_path_camp,
        any_completed_journey: journeys.any?
      )
    end

    private

    def build_rows(journeys)
      return [] if journeys.empty?

      journey_ids = journeys.map(&:id)
      goals_by_journey = @user.strategy_goals
        .for_kind("goal")
        .roots
        .where(life_journey_id: journey_ids)
        .index_by(&:life_journey_id)
      camps_by_journey = FinishedPathCamps.counts_by_journey(user: @user, journey_ids: journey_ids)
      zone = Time.find_zone!(@time_zone)

      journeys.map do |journey|
        goal = goals_by_journey[journey.id]
        title = goal&.title.presence || journey.title
        completed_on = journey.completed_at&.in_time_zone(zone)&.to_date
        Row.new(
          title: title,
          completed_on: completed_on,
          camps_count: camps_by_journey[journey.id].to_i
        )
      end
    end
  end
end
