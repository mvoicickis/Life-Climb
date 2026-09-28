# frozen_string_literal: true

module Strategy
  # Maps each camp (project) to battle strategy_goal ids under its tree (checklist hosts excluded).
  class BattleIdsByProject
    def self.call(user:, journey:, projects:)
      new(user: user, journey: journey, projects: projects).call
    end

    def initialize(user:, journey:, projects:)
      @user = user
      @journey = journey
      @projects = Array(projects)
    end

    def call
      return {} if @journey.blank? || @projects.empty?

      goals = @user.strategy_goals
        .where(life_journey_id: @journey.id)
        .select(:id, :parent_id, :horizon, :title)
        .to_a
      by_parent = goals.group_by(&:parent_id)

      @projects.each_with_object({}) do |project, memo|
        memo[project.id] = collect_battle_ids(project.id, by_parent)
      end
    end

    private

    def collect_battle_ids(node_id, by_parent)
      (by_parent[node_id] || []).flat_map do |child|
        if child.horizon == "day"
          EnsureFolderQuest.checklist_host?(child) ? [] : [ child.id ]
        else
          collect_battle_ids(child.id, by_parent)
        end
      end
    end
  end
end
