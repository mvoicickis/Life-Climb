# frozen_string_literal: true

module Strategy
  # Mountain % is project-gated, not battle-count.
  # Goal = average of plans. Plan = average of direct project percents.
  # Quantified path-level project = current_amount / target_amount (replaces binary/avg).
  # Leaf project = binary (completed_at). Branch project = recursive avg of child projects.
  # Battles never move year %.
  class Progress
    def self.percent(node)
      case node.kind
      when "day"
        node.completed_at.present? ? 100 : 0
      when "project"
        project_percent(node)
      when "plan"
        projects = child_nodes(node, "project")
        return 0 if projects.empty?

        (projects.sum { |project| percent(project) }.to_f / projects.size).round
      when "goal"
        plans = child_nodes(node, "plan")
        return 0 if plans.empty?

        (plans.sum { |plan| percent(plan) }.to_f / plans.size).round
      else
        0
      end
    end

    def self.project_percent(node)
      if node.quantified?
        target = node.target_amount.to_d
        return 0 if target <= 0

        ((node.current_amount.to_d / target) * 100).clamp(0, 100).round
      else
        child_projects = child_nodes(node, "project")
        if child_projects.any?
          (child_projects.sum { |project| percent(project) }.to_f / child_projects.size).round
        else
          node.completed_at.present? ? 100 : 0
        end
      end
    end
    private_class_method :project_percent

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
        next true if child.day?
        next false unless child.association(:children).loaded?

        child.children.all? { |grand| grand.association(:children).loaded? || grand.day? || grand.project? }
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
