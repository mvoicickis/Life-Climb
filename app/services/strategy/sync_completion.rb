# frozen_string_literal: true

module Strategy
  # After a project is marked done/reopened — or after structural mutations —
  # stamp or clear ancestors (nested branch checkpoints → plan → goal).
  # Sticky manual completes (manually_completed_at) are never auto-reopened.
  class SyncCompletion
    def self.call(project:)
      new(project).call
    end

    # Structural mutations (create/destroy Project or Plan, raise quantified
    # target). Accepts project, plan, or goal and reuses the same sync rules.
    def self.resync!(node:)
      return if node.blank?

      case node.kind
      when "project"
        align_project_stamp!(node)
        call(project: node)
      when "plan"
        sync = new(nil)
        sync.sync_plan!(node)
        goal = StrategyGoal.find_by(id: node.parent_id)
        sync.sync_goal!(goal) if goal&.goal?
      when "goal"
        new(nil).sync_goal!(node)
      end
    end

    def self.align_project_stamp!(project)
      return unless project&.project?
      return if project.manually_completed?

      if Strategy::Progress.percent(project) >= 100
        project.complete!
      else
        project.reopen!
      end
    end
    private_class_method :align_project_stamp!

    def initialize(project)
      @project = project
    end

    def call
      return unless @project&.project?

      node = @project
      while node
        parent = StrategyGoal.find_by(id: node.parent_id)
        break if parent.blank?

        if parent.project?
          sync_branch!(parent)
          node = parent
        elsif parent.plan?
          sync_plan!(parent)
          goal = StrategyGoal.find_by(id: parent.parent_id)
          sync_goal!(goal) if goal&.goal?
          break
        else
          break
        end
      end
    end

    def sync_branch!(branch)
      return if branch.manually_completed?

      projects = StrategyGoal.where(parent_id: branch.id, horizon: "project").to_a
      if projects.any? && projects.all? { |p| p.completed_at.present? }
        branch.complete!
      else
        branch.reopen!
      end
    end

    def sync_plan!(plan)
      return if plan.manually_completed?

      projects = StrategyGoal.where(parent_id: plan.id, horizon: "project").to_a
      if projects.any? && projects.all? { |p| project_satisfies_plan?(p) }
        plan.complete!
      else
        plan.reopen!
      end
    end

    def sync_goal!(goal)
      return if goal.blank?
      return if goal.manually_completed?

      plans = StrategyGoal.where(parent_id: goal.id, horizon: %w[plan]).to_a
      if plans.any? && plans.all? { |plan| plan_satisfies_goal?(plan) }
        goal.complete!
      else
        goal.reopen!
      end
    end

    private

    def project_satisfies_plan?(project)
      project.manually_completed? || Strategy::Progress.percent(project) >= 100
    end

    def plan_satisfies_goal?(plan)
      plan.manually_completed? || Strategy::Progress.percent(plan) >= 100
    end
  end
end
