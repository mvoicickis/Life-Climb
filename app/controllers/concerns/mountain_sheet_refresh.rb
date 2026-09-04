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
    assign_mountain_climber_context!
  end

  # Base camp Basics habit log — scope every id through current_user.
  def assign_mountain_sheet_for_base_camp!
    @journey = current_user.life_journeys.find(params.require(:life_journey_id))
    @goal = current_user.strategy_goals.for_kind("goal").find(params.require(:goal_id))
    @plan = current_user.strategy_goals.for_kind("plan").find(params.require(:plan_id))

    unless @plan.parent_id == @goal.id && mountain_goal_matches_journey?(@goal, @journey)
      raise ActiveRecord::RecordNotFound
    end

    projects = helpers.mountain_trail_open_camps(@plan)
    battles = projects.flat_map { |project|
      project.children.select { |child| child.day? && !child.holding? }
    }
    helpers.mountain_trail_preload_done_today!(current_user, battles)
    assign_mountain_climber_context!
  end

  def assign_mountain_climber_context!
    return if @plan.blank?

    @trail = Strategy::Trail.for(plan: @plan)
    @all_projects = helpers.mountain_trail_all_projects(@trail)
  end

  def mountain_goal_matches_journey?(goal, journey)
    return false if goal.blank? || journey.blank?

    goal.life_journey_id == journey.id || goal.life_area_id == journey.life_area_id
  end
  private :mountain_goal_matches_journey?

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
