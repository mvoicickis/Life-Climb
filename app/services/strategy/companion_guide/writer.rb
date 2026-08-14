# frozen_string_literal: true

module Strategy
  module CompanionGuide
    # Progressive create/update for guide answers. Mirrors FirstClimb#create_child!
    # shape without calling FirstClimb. Days hang on the path-level project.
    class Writer
      def self.call(user:, journey:, kind:, value:, cursor:)
        new(user:, journey:, kind:, value:, cursor:).call
      end

      def initialize(user:, journey:, kind:, value:, cursor:)
        @user = user
        @journey = journey
        @kind = kind.to_s
        @value = value
        @cursor = cursor.stringify_keys
        @area = journey.life_area
      end

      def call
        case @kind
        when "create_plan" then create_plan!
        when "set_effort_tier" then set_effort_tier!
        when "create_project" then create_project!
        when "create_day" then create_day!
        else
          raise ArgumentError, "unknown write kind: #{@kind}"
        end
      end

      private

      def create_plan!
        return @cursor if @cursor["plan_id"].present?

        title = @value.to_s.strip
        raise ArgumentError, I18n.t("strategy.companion_guide.errors.blank_title") if title.blank?

        goal = find_goal!
        plan = create_child!(parent: goal, horizon: "plan", title: title)
        Strategy::SyncCompletion.resync!(node: plan)
        @cursor.merge("plan_id" => plan.id, "goal_id" => goal.id)
      end

      def set_effort_tier!
        tier = @value.to_s.strip
        unless StrategyGoal::EFFORT_TIERS.include?(tier)
          raise ArgumentError, I18n.t("strategy.companion_guide.errors.bad_effort_tier")
        end

        plan = find_plan!
        plan.update!(effort_tier: tier)
        @cursor
      end

      def create_project!
        title = @value.to_s.strip
        raise ArgumentError, I18n.t("strategy.companion_guide.errors.blank_title") if title.blank?

        plan = find_plan!
        project = create_child!(parent: plan, horizon: "project", title: title)
        Strategy::SyncCompletion.resync!(node: project)
        @cursor.merge(
          "project_id" => project.id,
          "project_count" => @cursor["project_count"].to_i + 1,
          "step_count" => 0
        )
      end

      def create_day!
        title = @value.to_s.strip
        raise ArgumentError, I18n.t("strategy.companion_guide.errors.blank_title") if title.blank?

        project = find_project!
        create_child!(
          parent: project,
          horizon: "day",
          title: title,
          scheduled_on: Date.current
        )
        Strategy::CascadeToDaily.call(user: @user, life_area: @area)
        @cursor.merge("step_count" => @cursor["step_count"].to_i + 1)
      end

      def find_goal!
        goal = @user.strategy_goals.for_kind("goal").find_by(id: @cursor["goal_id"])
        goal ||= @user.strategy_goals.for_area(@area.id).for_kind("goal").roots.first
        raise ArgumentError, I18n.t("strategy.need_goal") if goal.blank?

        goal
      end

      def find_plan!
        plan = @user.strategy_goals.for_kind("plan").find_by(id: @cursor["plan_id"])
        raise ArgumentError, I18n.t("strategy.companion_guide.errors.missing_plan") if plan.blank?

        plan
      end

      def find_project!
        project = @user.strategy_goals.for_kind("project").find_by(id: @cursor["project_id"])
        raise ArgumentError, I18n.t("strategy.companion_guide.errors.missing_project") if project.blank?

        project
      end

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
