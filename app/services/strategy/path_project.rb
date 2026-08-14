# frozen_string_literal: true

module Strategy
  # Shared spine resolver for QuickAdd / EnsureDayForTodo / Handoff.
  # Picks an incomplete visible path-level Project (last-touched day ancestry
  # when ambiguous), or the hidden holding camp when none exist.
  class PathProject
    def self.resolve(user:, journey:)
      new(user:, journey:).resolve
    end

    def self.ensure!(user:, journey:, title:)
      new(user:, journey:).ensure!(title)
    end

    def initialize(user:, journey:)
      @user = user
      @journey = journey
    end

    def resolve
      goal = root_goal
      return nil if goal.blank?

      candidates = incomplete_path_projects(goal)
      return nil if candidates.empty?
      return candidates.first if candidates.size == 1

      candidate_ids = candidates.map(&:id).to_set
      camp = path_camp_ancestor(most_recent_day)
      return camp if camp && candidate_ids.include?(camp.id)

      candidates.first
    end

    def ensure!(_title)
      found = resolve
      return found if found

      HoldingProject.ensure!(user: @user, journey: @journey)
    end

    private

    def root_goal
      @root_goal ||= @user.strategy_goals
        .for_area(@journey.life_area_id)
        .for_kind("goal")
        .roots
        .first
    end

    def incomplete_path_projects(goal)
      goal.children.for_kind("plan").not_holding.ordered.flat_map do |plan|
        plan.children.for_kind("project").not_holding.ordered.select do |project|
          project.path_level_camp? && project.completed_at.blank?
        end
      end
    end

    def most_recent_day
      scope = @user.strategy_goals.where(
        life_area_id: @journey.life_area_id,
        horizon: "day"
      )
      scope = scope.where(life_journey_id: @journey.id) if @journey.id.present?
      scope.order(updated_at: :desc, id: :desc).first
    end

    def path_camp_ancestor(node)
      current = node
      while current
        return current if current.path_level_camp? && !current.holding?

        current = current.parent
      end
      nil
    end
  end
end
