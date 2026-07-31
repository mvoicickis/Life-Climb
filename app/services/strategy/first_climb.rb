# frozen_string_literal: true

module Strategy
  # Fast path for new climbers: plan title + today's action → full spine ready for Today.
  # Scaffolds under the Active Destination (goal) being onboarded — never a different root.
  class FirstClimb
    Result = Struct.new(:plan, :project, :battle, :goal, keyword_init: true)

    def self.call(user:, journey:, plan_title:, today_action:, goal: nil)
      new(user:, journey:, plan_title:, today_action:, goal:).call
    end

    def initialize(user:, journey:, plan_title:, today_action:, goal: nil)
      @user = user
      @journey = journey
      @plan_title = plan_title.to_s.strip
      @today_action = today_action.to_s.strip
      @goal = goal
    end

    def call
      raise ArgumentError, I18n.t("strategy.first_climb.need_plan") if @plan_title.blank?
      raise ArgumentError, I18n.t("strategy.first_climb.need_action") if @today_action.blank?

      area = @journey.life_area
      goal = resolve_goal(area)
      raise ArgumentError, I18n.t("strategy.need_goal") if goal.blank?

      result = nil
      ActiveRecord::Base.transaction do
        plan = create_child!(
          parent: goal,
          horizon: "plan",
          title: @plan_title,
          life_area: area
        )
        project = create_child!(
          parent: plan,
          horizon: "project",
          title: I18n.t("strategy.first_climb.project_title", plan: @plan_title.truncate(40)),
          life_area: area
        )
        battle = create_child!(
          parent: project,
          horizon: "day",
          title: @today_action,
          life_area: area,
          scheduled_on: Date.current
        )

        Strategy::CascadeToDaily.call(user: @user, life_area: area)
        mark_route_done!
        result = Result.new(plan: plan, project: project, battle: battle, goal: goal)
      end

      # One celebration for the day they just named — not three currency flashes.
      Strategy::Celebrate.call(user: @user, goal: result.battle)

      result
    end

    private

    def resolve_goal(area)
      if @goal.present?
        return @goal if @goal.user_id == @user.id && @goal.goal? && @goal.parent_id.nil? &&
                        @goal.life_area_id == area.id
      end

      @user.strategy_goals.for_area(area.id).for_kind("goal").roots.first
    end

    def create_child!(parent:, horizon:, title:, life_area:, scheduled_on: nil)
      scope = @user.strategy_goals.where(life_area_id: life_area.id).for_kind(horizon).where(parent_id: parent.id)
      position = scope.maximum(:position).to_i + 1
      @user.strategy_goals.create!(
        life_area: life_area,
        life_journey: @journey,
        parent: parent,
        horizon: horizon,
        title: title,
        scheduled_on: scheduled_on,
        position: position
      )
    end

    def mark_route_done!
      flags = (@journey.setup_flags.presence || {}).stringify_keys.merge(Onboarding::Run::ROUTE_FLAG => "done")
      @journey.update!(setup_flags: flags)
    end
  end
end
