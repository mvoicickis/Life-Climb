# frozen_string_literal: true

module Strategy
  # Reopens a finished battle camp for Arrange "Open again": manually_reopen!,
  # plant one new open day via CreateDayBattle (#510 path), place before later stages.
  # Does not reopen won battles or clear daily_todos.
  class ReopenPlanCamp
    class Invalid < StandardError; end

    def self.call(user:, camp:)
      new(user: user, camp: camp).call
    end

    def initialize(user:, camp:)
      @user = user
      @camp = camp
    end

    def call
      validate!

      StrategyGoal.transaction do
        @camp.manually_reopen!
        title = battle_title
        Strategy::CreateDayBattle.call(user: @user, project: @camp, title: title)
        plan = @camp.parent
        Strategy::PlaceCampOnStage.call(plan: plan, camp: @camp.reload, stage: @camp.stage.to_i)
        Strategy::SyncCompletion.resync!(node: @camp.reload)
      end

      @camp.reload
    end

    private

    def validate!
      raise Invalid, "camp_missing" if @camp.blank? || !@camp.project?
      raise Invalid, "not_authorized" unless @camp.user_id == @user.id
      raise Invalid, "not_completed" unless @camp.completed?
      raise Invalid, "quantified" if @camp.quantified?
      raise Invalid, "holding" if @camp.holding?
      raise Invalid, "not_plan_camp" unless @camp.parent&.plan?
    end

    def battle_title
      helpers = ApplicationController.helpers
      suggestion = helpers.mountain_trail_battle_suggestion(@camp)
      suggestion.presence ||
        Array(I18n.t("strategy.rpg.trail.battle_suggestions", default: [])).first.to_s.strip.presence ||
        "Take the first small step"
    end
  end
end
