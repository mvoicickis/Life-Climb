# frozen_string_literal: true

module Strategy
  module WeeklyPlanner
    # Creates N dated day StrategyGoals under the current leaf camp, then cascades.
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
        title = @cursor["title"].to_s.strip
        raise ArgumentError, I18n.t("strategy.weekly_planner.errors.blank_title") if title.blank?

        count = @cursor["sitting_count"].to_i
        raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_count") if count < 1

        dates = parse_dates(@cursor["selected_dates"])
        raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_dates") if dates.size != count

        eligible = Definition.eligible_dates(@user)
        unless dates.all? { |d| eligible.include?(d) }
          raise ArgumentError, I18n.t("strategy.weekly_planner.errors.bad_dates")
        end

        project = find_project!
        leaf = Battles::PracticeParent.call(user: @user, project: project)

        dates.sort.each do |date|
          create_child!(
            parent: leaf,
            horizon: "day",
            title: title,
            scheduled_on: date
          )
        end

        Strategy::CascadeToDaily.call(user: @user, life_area: @area)
        @cursor.merge(
          "status" => "completed",
          "selected_dates" => dates.map(&:iso8601),
          "project_id" => project.id
        )
      end

      private

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
