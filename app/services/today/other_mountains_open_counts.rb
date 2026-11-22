# frozen_string_literal: true

module Today
  # Open battle counts for the user's other active journeys (not the focused one).
  # Matches what Today would show after Cascade for that journey: incomplete
  # strategy-linked DailyTodos for the local day, plus due day-horizon
  # StrategyGoals that still have no DailyTodo row (uncascaded other areas).
  # Ad-hoc todos (strategy_goal_id nil) are excluded. Batched — no per-journey loops.
  class OtherMountainsOpenCounts
    Entry = Struct.new(:journey_id, :title, :open_count, :custom_photo, keyword_init: true) do
      def custom_photo?
        custom_photo
      end
    end

    Result = Struct.new(:journeys, :total, keyword_init: true)

    def self.call(user:, focused_journey:, date: nil)
      new(user:, focused_journey:, date:).call
    end

    def initialize(user:, focused_journey:, date: nil)
      @user = user
      @focused_journey = focused_journey
      @date = date
    end

    def call
      date = @date || Battles::WinsOnLocalDate.local_today_for(@user)
      focused_id = @focused_journey&.id

      journey_rows = @user.life_journeys.with_destination
        .where.not(id: focused_id)
        .left_outer_joins(:mountain_photo_attachment)
        .pluck(
          "life_journeys.id",
          "life_journeys.title",
          "active_storage_attachments.id"
        )
      return Result.new(journeys: [], total: 0) if journey_rows.empty?

      other_ids = journey_rows.map(&:first)
      titles_by_id = root_titles_by_journey_id(other_ids)
      open_by_id = Hash.new(0)

      incomplete_todo_counts(other_ids, date).each do |journey_id, count|
        open_by_id[journey_id] += count
      end
      uncascaded_counts(other_ids, date).each do |journey_id, count|
        open_by_id[journey_id] += count
      end

      journeys = journey_rows.filter_map do |journey_id, journey_title, attachment_id|
        count = open_by_id[journey_id].to_i
        next if count <= 0

        Entry.new(
          journey_id: journey_id,
          title: titles_by_id[journey_id].presence || journey_title,
          open_count: count,
          custom_photo: attachment_id.present?
        )
      end

      journeys.sort_by! { |entry| [ -entry.open_count, entry.title.to_s.downcase ] }
      Result.new(journeys: journeys, total: journeys.sum(&:open_count))
    end

    private

    def root_titles_by_journey_id(other_ids)
      titles = {}
      @user.strategy_goals
        .for_kind("goal")
        .roots
        .where(life_journey_id: other_ids)
        .order(:position, :id)
        .pluck(:life_journey_id, :title)
        .each { |journey_id, title| titles[journey_id] ||= title }
      titles
    end

    def incomplete_todo_counts(other_ids, date)
      @user.daily_todos
        .for_day(date)
        .incomplete
        .where.not(strategy_goal_id: nil)
        .joins(:strategy_goal)
        .where(strategy_goals: { life_journey_id: other_ids })
        .group("strategy_goals.life_journey_id")
        .count
    end

    # Day battles DueDayBattles would sync for +date+ that still have no DailyTodo
    # row (cascade has not run for that area yet). Weekly rows filtered in Ruby.
    def uncascaded_counts(other_ids, date)
      surfaced_scope = @user.daily_todos.for_day(date).where.not(strategy_goal_id: nil)

      rows = @user.strategy_goals
        .battles
        .incomplete
        .not_holding
        .where(life_journey_id: other_ids)
        .where(repeat: %w[none daily weekly])
        .where("scheduled_on IS NULL OR scheduled_on <= ?", date)
        .where.not(id: surfaced_scope.select(:strategy_goal_id))
        .pluck(:life_journey_id, :repeat, :repeat_weekdays)

      counts = Hash.new(0)
      rows.each do |journey_id, repeat, weekdays|
        case repeat.to_s
        when "none", "daily"
          counts[journey_id] += 1
        when "weekly"
          wdays = Array(weekdays).map(&:to_i)
          counts[journey_id] += 1 if wdays.include?(date.wday)
        end
      end
      counts
    end
  end
end
