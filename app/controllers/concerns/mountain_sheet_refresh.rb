# frozen_string_literal: true

# Assigns camp/plan locals so Mountain can replace battle lists in place.
module MountainSheetRefresh
  private

  def assign_mountain_sheet_for!(node)
    battle = node&.day? ? node : nil
    project = mountain_camp_for(node)
    project&.reload
    plan = project&.parent if project&.parent&.plan?
    plan ||= project&.ancestor_chain&.reverse&.find(&:plan?)
    plan ||= node&.ancestor_chain&.reverse&.find(&:plan?)
    plan&.reload

    @battle = battle if battle
    @project = project
    @plan = plan
    @goal = node&.root_goal || project&.root_goal
    @journey = node&.life_journey || project&.life_journey || current_user.primary_focused_journey
    preload_mountain_done_today_for_project!(project)
  end

  def preload_mountain_done_today_for_project!(project)
    return if project.blank?

    battles = project.children.select { |child| child.day? && !child.holding? }
    helpers.mountain_trail_preload_done_today!(current_user, battles)
  end

  # Camp sheets sit on plan-level projects. Nested practice leaves walk up.
  def mountain_camp_for(node)
    return node if node&.project? && node.parent&.plan?

    cursor = node&.day? ? node.parent : node
    while cursor
      return cursor if cursor.project? && cursor.parent&.plan?

      cursor = cursor.parent
    end

    start = node&.day? ? node.parent : node
    start if start&.project?
  end
end
