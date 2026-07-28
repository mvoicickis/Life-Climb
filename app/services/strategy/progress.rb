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

    def self.child_nodes(node, kind)
      kids =
        if node.association(:children).loaded?
          node.children.sort_by { |c| [ c.position.to_i, c.id ] }
        else
          StrategyGoal.where(parent_id: node.id).ordered.to_a
        end
      kids.select { |child| child.kind == kind }
    end
    private_class_method :child_nodes

    # Prefer a preloaded tree when available — Goal→Plan→Project→Battle in one walk.
    def self.battles_under(node)
      return [ node ] if node.day?

      if fully_preloaded?(node)
        return collect_battles(node).sort_by { |b| [ b.scheduled_on || Date.new(9999), b.position.to_i, b.id ] }
      end

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

    def self.fully_preloaded?(node)
      return false unless node.association(:children).loaded?

      node.children.all? do |child|
        child.association(:children).loaded? &&
          child.children.all? { |grand| grand.association(:children).loaded? || grand.day? }
      end
    end
    private_class_method :fully_preloaded?

    def self.collect_battles(node)
      return [ node ] if node.day?

      node.children.flat_map { |child| collect_battles(child) }
    end
    private_class_method :collect_battles
  end
end
