# frozen_string_literal: true

module Strategy
  # Shared spine resolver for QuickAdd / EnsureDayForTodo / Handoff.
  # Picks an incomplete path-level Project (last-touched day ancestry when ambiguous),
  # or auto-creates a minimal Plan + path Project named from a battle title.
  class PathProject
    TITLE_MAX = 60

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

    def ensure!(title)
      found = resolve
      return found if found

      goal = root_goal
      return nil if goal.blank?

      name = title.to_s.strip.truncate(TITLE_MAX)
      return nil if name.blank?

      plan = goal.children.for_kind("plan").ordered.first
      if plan.nil?
        plan = goal.children.create!(
          user: @user,
          life_area: @journey.life_area,
          life_journey: @journey,
          horizon: "plan",
          title: name,
          position: next_child_position(goal)
        )
        Strategy::SyncCompletion.resync!(node: plan)
      end

      project = plan.children.create!(
        user: @user,
        life_area: @journey.life_area,
        life_journey: @journey,
        horizon: "project",
        title: name,
        position: next_child_position(plan)
      )
      Strategy::SyncCompletion.resync!(node: project)
      project
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
      goal.children.for_kind("plan").ordered.flat_map do |plan|
        plan.children.for_kind("project").ordered.select do |project|
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
        return current if current.path_level_camp?

        current = current.parent
      end
      nil
    end

    def next_child_position(parent)
      parent.children.maximum(:position).to_i + 1
    end
  end
end
