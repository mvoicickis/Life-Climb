# frozen_string_literal: true

module MountainTrail
  # Resolves the user's current camp and first open battle for notifications.
  class CurrentFocus
    Result = Struct.new(:journey, :goal, :plan, :camp, :battle, keyword_init: true)

    def self.for(user:)
      new(user:).call
    end

    # Lowest on trail (highest y) with an open battle — matches mountain_trail_current_project.
    def self.current_project(projects)
      eligible = Array(projects).reject(&:completed?).reject(&:pages_mode?).select do |project|
        project.children.any? { |child| child.day? && !child.holding? && !child.completed? }
      end
      return nil if eligible.empty?

      layout = layout_for(eligible)
      eligible.max_by { |project| layout.dig(project.id, :y).to_f }
    end

    def self.first_open_battle(project)
      return nil if project.blank?

      project.children
        .select { |child| child.day? && !child.holding? && !child.completed? }
        .min_by { |child| [ child.position.to_i, child.id ] }
    end

    def self.layout_for(projects)
      list = Array(projects)
      list.each_with_index.to_h do |project, index|
        slot = slot_for(project, index: index, total: list.size)
        [ project.id, { y: slot[:y].to_f } ]
      end
    end

    def self.slot_for(project, index:, total:)
      if project.trail_x.present? && project.trail_y.present?
        snap = MountainTrailHelper::AutoSlot.snap(project.trail_x, project.trail_y)
        { y: snap[:trail_y] }
      else
        { y: MountainTrailHelper::AutoSlot.y_for(index, total) }
      end
    end

    def initialize(user:)
      @user = user
    end

    def call
      journey = @user.primary_focused_journey
      return empty if journey.blank?

      goal = @user.strategy_goals.for_area(journey.life_area_id).for_kind("goal").roots.first
      return empty if goal.blank?

      plan = goal.children.for_kind("plan").not_holding.ordered.first
      return empty if plan.blank?

      projects = plan.children.for_kind("project").not_holding.includes(:children).ordered.to_a
      projects.reject!(&:completed?)

      camp = self.class.current_project(projects)
      battle = self.class.first_open_battle(camp)

      Result.new(journey: journey, goal: goal, plan: plan, camp: camp, battle: battle)
    end

    private

    def empty
      Result.new(journey: nil, goal: nil, plan: nil, camp: nil, battle: nil)
    end
  end
end
