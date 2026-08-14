# frozen_string_literal: true

module Strategy
  # Fast path for new climbers: plan title + today's action → full spine ready for Today.
  class FirstClimb
    Result = Struct.new(:plan, :project, :battle, :goal, :created, keyword_init: true) do
      def created?
        created
      end
    end

    def self.call(user:, journey:, plan_title:, today_action:, goal: nil, goal_title: nil)
      new(user:, journey:, plan_title:, today_action:, goal:, goal_title:).call
    end

    def initialize(user:, journey:, plan_title:, today_action:, goal: nil, goal_title: nil)
      @user = user
      @journey = journey
      @plan_title = plan_title.to_s.strip
      @today_action = today_action.to_s.strip
      @goal = goal
      @goal_title = goal_title.to_s.strip.presence
    end

    def call
      raise ArgumentError, I18n.t("strategy.first_climb.need_plan") if @plan_title.blank?
      raise ArgumentError, I18n.t("strategy.first_climb.need_action") if @today_action.blank?
      raise ArgumentError, I18n.t("strategy.need_goal") if @goal.blank? && @goal_title.blank?

      area = @journey.life_area
      raise ArgumentError, I18n.t("strategy.need_goal") if area.blank?

      result = nil
      goal = resolve_goal!(area)
      # Lock the destination we will climb so two near-simultaneous posts
      # cannot both pass the empty-spine check before either commits.
      goal.with_lock do
        @journey.reload
        goal.reload
        if already_climbed?(goal)
          result = existing_result_for(goal)
        else
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
          result = Result.new(plan: plan, project: project, battle: battle, goal: goal, created: true)
        end
      end

      # One celebration for the day they just named — not on idempotent retries.
      Strategy::Celebrate.call(user: @user, goal: result.battle) if result.created? && result.battle

      result
    end

    private

    def already_climbed?(goal)
      goal.children.for_kind("plan").not_holding.exists?
    end

    def resolve_goal!(area)
      if @goal_title.present?
        create_root_goal!(area)
      elsif @goal.present?
        @goal
      else
        raise ArgumentError, I18n.t("strategy.need_goal")
      end
    end

    def create_root_goal!(area)
      scope = @user.strategy_goals.where(life_area_id: area.id).for_kind("goal").roots
      position = scope.maximum(:position).to_i + 1
      @user.strategy_goals.create!(
        life_area: area,
        life_journey: @journey,
        parent: nil,
        horizon: "goal",
        title: @goal_title,
        position: position
      )
    end

    def existing_result_for(goal)
      plan = goal.children.for_kind("plan").not_holding.ordered.first
      project = plan&.children&.for_kind("project")&.not_holding&.ordered&.first
      battle = project&.children&.for_kind("day")&.ordered&.first

      Result.new(plan: plan, project: project, battle: battle, goal: goal, created: false)
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
      flags = (@journey.setup_flags.presence || {}).stringify_keys
      return if flags[Onboarding::Run::ROUTE_FLAG] == "done"

      @journey.update!(setup_flags: flags.merge(Onboarding::Run::ROUTE_FLAG => "done"))

      # Retire the scaffolding "Plan Your Route" mission now — otherwise Today
      # still lists it beside the real first-climb action (retire_plan_route_if_needed!
      # only runs while the route flag is still "pending").
      mission = @journey.missions.for_day(Date.current).primary.incomplete.order(:id).first
      mission&.update!(status: "replaced")
    end
  end
end
