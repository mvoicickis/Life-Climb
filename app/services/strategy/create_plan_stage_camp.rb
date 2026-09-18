# frozen_string_literal: true

module Strategy
  # Plants a new camp on an explicit terrace stage (Arrange "+ Add a camp here").
  # Uses stage_explicit so assign_stage_for_plan_camp / assign_open_stage! cannot override.
  class CreatePlanStageCamp
    class Invalid < StandardError; end

    def self.call(user:, plan:, stage:, title:)
      new(user: user, plan: plan, stage: stage, title: title).call
    end

    def initialize(user:, plan:, stage:, title:)
      @user = user
      @plan = plan
      @stage = stage.to_i
      @title = title.to_s.strip
    end

    def call
      validate!

      camp = nil
      StrategyGoal.transaction do
        camp = @user.strategy_goals.new(
          life_area: @plan.life_area,
          life_journey_id: @plan.life_journey_id,
          parent: @plan,
          horizon: "project",
          title: @title,
          position: 0,
          stage: @stage
        )
        camp.stage_explicit = true
        camp.save!
        Strategy::PlaceCampOnNewTerrace.place_on_stage!(plan: @plan, camp: camp, stage: @stage)
        Strategy::Celebrate.call(user: @user, goal: camp)
        Strategy::SyncCompletion.resync!(node: camp.reload)
      end
      camp.reload
    end

    private

    def validate!
      raise Invalid, "plan_missing" if @plan.blank? || !@plan.plan?
      raise Invalid, "not_authorized" unless @plan.user_id == @user.id
      raise Invalid, "blank_title" if @title.blank?
      raise Invalid, "bad_stage" if @stage.negative?
    end
  end
end
