# frozen_string_literal: true

module Strategy
  # One-time collapse of month/week nodes into Goal → Plan → Project → Battle.
  class CollapseMonths
    def self.call
      new.call
    end

    def call
      StrategyGoal.where(horizon: "month").order(:id).find_each do |month|
        project = ensure_project_for(month)
        reparent_battles!(month, project)
        destroy_subtree!(month)
      end

      StrategyGoal.where(horizon: "week").find_each do |week|
        project = nearest_project(week) || invent_project_from(week)
        reparent_battles!(week, project) if project
        destroy_subtree!(week)
      end
    end

    private

    def ensure_project_for(month)
      parent = month.parent
      return parent if parent&.project?

      if parent&.plan?
        existing = parent.children.find_by(horizon: "project", title: month.title)
        return existing if existing

        parent.children.create!(
          user_id: month.user_id,
          life_area_id: month.life_area_id,
          life_journey_id: month.life_journey_id,
          horizon: "project",
          title: month.title.presence || parent.title,
          due_on: parent.due_on || month.due_on,
          position: next_position(parent, "project")
        )
      else
        invent_project_from(month)
      end
    end

    def invent_project_from(node)
      plan = node.ancestor_chain.reverse.find(&:plan?) || node.parent
      return unless plan&.plan?

      plan.children.create!(
        user_id: node.user_id,
        life_area_id: node.life_area_id,
        life_journey_id: node.life_journey_id,
        horizon: "project",
        title: node.title.presence || plan.title,
        due_on: plan.due_on,
        position: next_position(plan, "project")
      )
    end

    def nearest_project(node)
      return node if node.project?
      return node.parent if node.parent&.project?

      node.ancestor_chain.reverse.find(&:project?)
    end

    def reparent_battles!(from_node, project)
      return if project.blank?

      battle_ids = descendant_battle_ids(from_node)
      return if battle_ids.empty?

      max_pos = project.children.where(horizon: "day").maximum(:position).to_i
      StrategyGoal.where(id: battle_ids).find_each.with_index do |battle, index|
        battle.update_columns(
          parent_id: project.id,
          position: max_pos + index + 1,
          updated_at: Time.current
        )
      end
    end

    def descendant_battle_ids(node)
      ids = []
      queue = [ node.id ]
      while queue.any?
        parent_id = queue.shift
        StrategyGoal.where(parent_id: parent_id).find_each do |child|
          if child.horizon == "day"
            ids << child.id
          else
            queue << child.id
          end
        end
      end
      ids
    end

    def destroy_subtree!(node)
      node.reload
      node.children.where(horizon: %w[week month]).find_each { |child| destroy_subtree!(child) }
      # Battles should already be reparented; destroy any leftover non-day children then the node.
      node.children.where.not(horizon: "day").delete_all
      node.children.where(horizon: "day").update_all(parent_id: node.parent_id) if node.parent_id
      node.delete
    end

    def next_position(parent, kind)
      parent.children.where(horizon: kind).maximum(:position).to_i + 1
    end
  end
end
