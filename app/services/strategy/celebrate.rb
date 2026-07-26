# frozen_string_literal: true

module Strategy
  # Milestone SP celebrations for the guided Strategy V1 flow.
  class Celebrate
    REASONS = {
      goal_created: "goal_created",
      first_plan: "first_plan",
      first_project: "first_project",
      strategy_complete: "strategy_complete",
      child: "child_planned"
    }.freeze

    def self.call(user:, goal:)
      new(user:, goal:).call
    end

    def initialize(user:, goal:)
      @user = user
      @goal = goal
      @awarded = 0
    end

    def call
      notice =
        case @goal.kind
        when "goal"
          award(GameRules::STRATEGY_GOAL_SP, REASONS[:goal_created], @goal)
          I18n.t("strategy.celebrate.goal", sp: GameRules::STRATEGY_GOAL_SP)
        when "plan"
          if first_of_kind?("plan")
            award(GameRules::STRATEGY_FIRST_PLAN_SP, REASONS[:first_plan], @goal)
            I18n.t("strategy.celebrate.first_plan", sp: GameRules::STRATEGY_FIRST_PLAN_SP)
          else
            award(GameRules::STRATEGY_CHILD_SP, REASONS[:child], @goal)
            I18n.t("strategy.created", sp: GameRules::STRATEGY_CHILD_SP)
          end
        when "project"
          if first_of_kind?("project")
            award(GameRules::STRATEGY_FIRST_PROJECT_SP, REASONS[:first_project], @goal)
            I18n.t("strategy.celebrate.first_project", sp: GameRules::STRATEGY_FIRST_PROJECT_SP)
          else
            award(GameRules::STRATEGY_CHILD_SP, REASONS[:child], @goal)
            I18n.t("strategy.created", sp: GameRules::STRATEGY_CHILD_SP)
          end
        else
          award(GameRules::STRATEGY_CHILD_SP, REASONS[:child], @goal)
          base = I18n.t("strategy.created", sp: GameRules::STRATEGY_CHILD_SP)
          bonus = complete_bonus_notice
          bonus ? "#{base} · #{bonus}" : base
        end

      { notice: notice, amount: @awarded }
    end

    private

    def award(amount, reason, source)
      amount = amount.to_i
      return if amount.zero?
      return if already_awarded?(reason, source)

      Strategy::Award.call(user: @user, amount: amount, reason: reason, source: source)
      @awarded += amount
    end

    def already_awarded?(reason, source)
      scope = @user.strategy_point_ledgers.where(reason: reason)
      if reason.in?([ REASONS[:first_plan], REASONS[:first_project], REASONS[:strategy_complete] ])
        return scope.exists?
      end

      scope.where(source: source).exists?
    end

    def first_of_kind?(kind)
      @user.strategy_goals.for_kind(kind).where.not(id: @goal.id).none?
    end

    def complete_bonus_notice
      root = @goal.root_goal
      return unless root&.goal?
      return unless strategy_path_complete?(root)
      return if already_awarded?(REASONS[:strategy_complete], root)

      award(GameRules::STRATEGY_COMPLETE_SP, REASONS[:strategy_complete], root)
      I18n.t("strategy.celebrate.strategy_complete", sp: GameRules::STRATEGY_COMPLETE_SP)
    end

    def strategy_path_complete?(root)
      plan_ids = root.children.for_kind("plan").pluck(:id)
      return false if plan_ids.empty?

      project_ids = StrategyGoal.where(parent_id: plan_ids).for_kind("project").pluck(:id)
      return false if project_ids.empty?

      Strategy::Progress.battles_under(root).any?
    end
  end
end
