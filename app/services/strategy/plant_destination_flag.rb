# frozen_string_literal: true

module Strategy
  # Mockup Step 1: confirm destination on the mountain, scaffold an empty Plan only.
  # User plants the first Project on the trail afterward (no auto project/battle).
  class PlantDestinationFlag
    Result = Struct.new(:goal, :plan, :created, keyword_init: true) do
      def created?
        created
      end
    end

    def self.call(user:, journey:, goal:, title:)
      new(user:, journey:, goal:, title:).call
    end

    def initialize(user:, journey:, goal:, title:)
      @user = user
      @journey = journey
      @goal = goal
      @title = title.to_s.strip
    end

    def call
      raise ArgumentError, I18n.t("strategy.need_goal") if @goal.blank?
      raise ArgumentError, I18n.t("strategy.rpg.trail.destination_blank") if @title.blank?

      area = @journey.life_area
      raise ArgumentError, I18n.t("strategy.need_goal") if area.blank?

      result = nil
      @goal.with_lock do
        @goal.reload
        @goal.update!(title: @title)

        existing = @goal.children.for_kind("plan").not_holding.ordered.first
        if existing
          result = Result.new(goal: @goal, plan: existing, created: false)
        else
          plan = @user.strategy_goals.create!(
            life_area: area,
            life_journey: @journey,
            parent: @goal,
            horizon: "plan",
            title: I18n.t("strategy.rpg.trail.default_plan_title"),
            position: next_position(@goal, "plan")
          )
          mark_route_done!
          result = Result.new(goal: @goal, plan: plan, created: true)
        end
      end

      result
    end

    private

    def next_position(parent, kind)
      scope = @user.strategy_goals.where(life_area_id: parent.life_area_id).for_kind(kind).where(parent_id: parent.id)
      scope.maximum(:position).to_i + 1
    end

    def mark_route_done!
      flags = (@journey.setup_flags.presence || {}).stringify_keys
      return if flags[Onboarding::Run::ROUTE_FLAG] == "done"

      @journey.update!(setup_flags: flags.merge(Onboarding::Run::ROUTE_FLAG => "done"))
      mission = @journey.missions.for_day(Date.current).primary.incomplete.order(:id).first
      mission&.update!(status: "replaced")
    end
  end
end
