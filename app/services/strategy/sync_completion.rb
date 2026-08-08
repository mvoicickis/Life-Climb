# frozen_string_literal: true

module Strategy
  # After a project is marked done/reopened — or after structural mutations —
  # stamp or clear ancestors (nested branch checkpoints → plan → goal).
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
      projects = StrategyGoal.where(parent_id: branch.id, horizon: "project").to_a
      if projects.any? && projects.all? { |p| p.completed_at.present? }
        branch.complete!
      else
        branch.reopen!
      end
    end

    def sync_plan!(plan)
      projects = StrategyGoal.where(parent_id: plan.id, horizon: "project").to_a
      if projects.any? && projects.all? { |p| Strategy::Progress.percent(p) >= 100 }
        plan.complete!
      else
        plan.reopen!
      end
    end

    def sync_goal!(goal)
      return if goal.blank?

      plans = StrategyGoal.where(parent_id: goal.id, horizon: %w[plan]).to_a
      if plans.any? && plans.all? { |plan| Strategy::Progress.percent(plan) >= 100 }
        goal.complete!
      else
        goal.reopen!
      end
    end
  end
end
