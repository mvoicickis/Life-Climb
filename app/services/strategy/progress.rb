# frozen_string_literal: true

module Strategy
  # Progress = completed descendant battles / total battles under a node.
  class Progress
    def self.percent(node)
      list = battles_under(node)
      return 0 if list.empty?

      done = list.count { |b| b.completed_at.present? }
      ((done.to_f / list.size) * 100).round
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
  end
end
