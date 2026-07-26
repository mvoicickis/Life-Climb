# frozen_string_literal: true

module Strategy
  # After a project is marked done/reopened, stamp or clear plan + goal completed_at.
  class SyncCompletion
    def self.call(project:)
      new(project).call
    end

    def initialize(project)
      @project = project
    end

    def call
      return unless @project&.project?

      plan = StrategyGoal.find_by(id: @project.parent_id)
      return unless plan&.plan?

      sync_plan!(plan)
      goal = StrategyGoal.find_by(id: plan.parent_id)
      sync_goal!(goal) if goal&.goal?
    end

    private

    def sync_plan!(plan)
      projects = StrategyGoal.where(parent_id: plan.id, horizon: "project").to_a
      if projects.any? && projects.all? { |p| p.completed_at.present? }
        plan.complete!
      else
        plan.reopen!
      end
    end

    def sync_goal!(goal)
      plans = StrategyGoal.where(parent_id: goal.id, horizon: %w[plan]).to_a
      # legacy "year" roots are goals; child plans use horizon plan
      if plans.any? && plans.all? { |plan| Strategy::Progress.percent(plan) >= 100 }
        goal.complete!
      else
        goal.reopen!
      end
    end
  end
end
