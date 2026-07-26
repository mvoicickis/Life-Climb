# frozen_string_literal: true

module Strategy
  # Mountain % is project-gated, not battle-count.
  # Goal = average of plans (equal weight). Plan = completed projects / projects.
  # Battles never move year %.
  class Progress
    def self.percent(node)
      case node.kind
      when "day", "project"
        node.completed_at.present? ? 100 : 0
      when "plan"
        projects = child_nodes(node, "project")
        return 0 if projects.empty?

        done = projects.count { |p| p.completed_at.present? }
        ((done.to_f / projects.size) * 100).round
      when "goal"
        plans = child_nodes(node, "plan")
        return 0 if plans.empty?

        (plans.sum { |plan| percent(plan) }.to_f / plans.size).round
      else
        0
      end
    end

    def self.battles_under(node)
      return [ node ] if node.day?

      ids = [ node.id ]
      frontier = [ node.id ]
      while frontier.any?
        kids = StrategyGoal.where(parent_id: frontier).pluck(:id)
        break if kids.empty?

        ids.concat(kids)
        frontier = kids
      end

      StrategyGoal.where(id: ids, horizon: "day").ordered.to_a
    end

    def self.child_nodes(node, kind)
      StrategyGoal.where(parent_id: node.id).ordered.select { |child| child.kind == kind }
    end
    private_class_method :child_nodes
  end
end
