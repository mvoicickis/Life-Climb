# frozen_string_literal: true

module Strategy
  module WeeklyPlanner
    # Creates day StrategyGoals for every item × its selected days, then cascades.
    # Returns the completed cursor payload including created_count and skipped.
    class Writer
      def self.call(user:, journey:, cursor:)
        new(user:, journey:, cursor:).call
      end

      def initialize(user:, journey:, cursor:)
        @user = user
        @journey = journey
        @cursor = cursor.stringify_keys
        @area = journey.life_area
      end

      def call
        items = Array(@cursor["items"])
        raise ArgumentError, I18n.t("strategy.weekly_planner.errors.blank_title") if items.empty?

        project = find_project!
        leaf = Battles::PracticeParent.call(user: @user, project: project)

        reserved = Hash.new(0)
        created_goals = []
        skipped = []

        items.each do |item|
          title = item["title"].to_s.strip
          raise ArgumentError, I18n.t("strategy.weekly_planner.errors.blank_title") if title.blank?

          dates = parse_dates(item["selected_dates"])
          if dates.empty?
            raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_dates")
          end

          dates.sort.each do |date|
            unless date_in_week?(date)
              raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_dates")
            end

            used = @user.daily_todos.for_day(date).count + reserved[date]
            if used >= GameRules::MAX_DAILY_TODOS
              skipped << { "title" => title, "date" => date.iso8601 }
              next
            end

            goal = create_child!(
              parent: leaf,
              horizon: "day",
              title: title,
              scheduled_on: date
            )
            created_goals << { goal: goal, title: title, date: date }
            reserved[date] += 1
          end
        end

        if created_goals.empty? && skipped.any?
          # Nothing to cascade — still complete honestly.
          return completed_cursor(project: project, items: items, created_count: 0, skipped: skipped)
        end

        raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_dates") if created_goals.empty?

        Strategy::CascadeToDaily.call(user: @user, life_area: @area)

        # Safety net for races (another tab filled the day between create and cascade).
        cascade_skipped = created_goals.filter_map do |row|
          exists = @user.daily_todos.exists?(
            strategy_goal_id: row[:goal].id,
            scheduled_on: row[:date]
          )
          next if exists

          { "title" => row[:title], "date" => row[:date].iso8601 }
        end

        skipped.concat(cascade_skipped)
        created_count = created_goals.size - cascade_skipped.size
        completed_cursor(project: project, items: items, created_count: created_count, skipped: skipped)
      end

      private

      def completed_cursor(project:, items:, created_count:, skipped:)
        @cursor.merge(
          "status" => "completed",
          "template_id" => "pick_days",
          "project_id" => project.id,
          "created_count" => created_count,
          "skipped" => skipped,
          "items" => items
        )
      end

      def find_project!
        project = @user.strategy_goals.for_kind("project").find_by(id: @cursor["project_id"])
        raise ArgumentError, I18n.t("strategy.weekly_planner.errors.missing_project") if project.blank?

        project
      end

      def parse_dates(raw)
        Array(raw).filter_map do |value|
          Date.iso8601(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end.uniq
      end

      def date_in_week?(date)
        range = Date.current..Date.current.end_of_week
        range.cover?(date)
      end

      # Duplicates Strategy::CompanionGuide::Writer#create_child!.
      # Extract to a shared concern when a third caller appears — two copies will drift silently otherwise.
      def create_child!(parent:, horizon:, title:, scheduled_on: nil)
        scope = @user.strategy_goals.where(life_area_id: @area.id).for_kind(horizon).where(parent_id: parent.id)
        position = scope.maximum(:position).to_i + 1
        @user.strategy_goals.create!(
          life_area: @area,
          life_journey: @journey,
          parent: parent,
          horizon: horizon,
          title: title,
          scheduled_on: scheduled_on,
          position: position
        )
      end
    end
  end
end
