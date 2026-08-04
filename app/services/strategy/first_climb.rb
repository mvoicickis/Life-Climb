# frozen_string_literal: true

module Strategy
  # Fast path for new climbers: plan title + today's action → full spine ready for Today.
  class FirstClimb
    Result = Struct.new(:plan, :project, :battle, :goal, :created, keyword_init: true) do
      def created?
        created
      end
    end

    def self.call(user:, journey:, plan_title:, today_action:)
      new(user:, journey:, plan_title:, today_action:).call
    end

    def initialize(user:, journey:, plan_title:, today_action:)
      @user = user
      @journey = journey
      @plan_title = plan_title.to_s.strip
      @today_action = today_action.to_s.strip
    end

    def call
      raise ArgumentError, I18n.t("strategy.first_climb.need_plan") if @plan_title.blank?
      raise ArgumentError, I18n.t("strategy.first_climb.need_action") if @today_action.blank?

      area = @journey.life_area
      goal = @user.strategy_goals.for_area(area.id).for_kind("goal").roots.first
      raise ArgumentError, I18n.t("strategy.need_goal") if goal.blank?

      result = nil
      # with_lock reloads + row-locks the goal so two near-simultaneous posts
      # cannot both pass the empty-spine check before either commits.
      goal.with_lock do
        @journey.reload
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
          # Dailies hang under a nested camp, not directly on the Path-level camp.
          nested = create_child!(
            parent: project,
            horizon: "project",
            title: I18n.t("strategy.first_climb.nested_camp_title"),
            life_area: area
          )
          battle = create_child!(
            parent: nested,
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
      route_done? || goal.children.for_kind("plan").exists?
    end

    def route_done?
      (@journey.setup_flags.presence || {}).stringify_keys[Onboarding::Run::ROUTE_FLAG] == "done"
    end

    def existing_result_for(goal)
      plan = goal.children.for_kind("plan").ordered.first
      project = plan&.children&.for_kind("project")&.ordered&.first
      nested = project&.children&.for_kind("project")&.ordered&.first
      battle =
        nested&.children&.for_kind("day")&.ordered&.first ||
        project&.children&.for_kind("day")&.ordered&.first

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
      flags = (@journey.setup_flags.presence || {}).stringify_keys.merge(Onboarding::Run::ROUTE_FLAG => "done")
      @journey.update!(setup_flags: flags)

      # Retire the scaffolding "Plan Your Route" mission now — otherwise Today
      # still lists it beside the real first-climb action (retire_plan_route_if_needed!
      # only runs while the route flag is still "pending").
      mission = @journey.missions.for_day(Date.current).primary.incomplete.order(:id).first
      mission&.update!(status: "replaced")
    end
  end
end
