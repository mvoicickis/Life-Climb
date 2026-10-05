# frozen_string_literal: true

# Turbo swap between summit scene and map world when all path camps finish / reopen.
module TrailMountainSummitSwap
  extend ActiveSupport::Concern

  private

  def capture_trail_summit_was_summit!(plan)
    @trail_summit_was_summit = trail_summit_reached_for_swap?(plan) if plan.present?
  end

  def trail_summit_reached_for_swap?(plan, destination_overlay: nil)
    return false if plan.blank?

    journey = @journey || plan.life_journey || current_user.primary_focused_journey
    goal = @goal || plan.root_goal
    return false if journey.blank?

    overlay = destination_overlay.nil? ? @trail_destination_overlay : destination_overlay
    trail = Strategy::Trail.for(plan: plan)
    helpers.trail_mountain_world_locals(
      trail: trail,
      goal: goal,
      plan: plan,
      journey: journey,
      destination_overlay: overlay,
      plans: @plans || []
    )[:summit_reached]
  end

  def prepare_trail_mountain_summit_swap!(plan:, journey: nil, goal: nil, destination_overlay: nil, plans: [])
    @trail_summit_state_flipped = false
    return if plan.blank?

    @journey = journey if journey.present?
    @journey ||= plan.life_journey || current_user.primary_focused_journey
    @goal = goal if goal.present?
    @goal ||= plan.root_goal
    @trail_destination_overlay = destination_overlay unless destination_overlay.nil?
    @plans = plans if plans.present?

    was_summit = @trail_summit_was_summit
    was_summit = trail_summit_reached_for_swap?(plan) if was_summit.nil?

    plan.reload
    trail = Strategy::Trail.for(plan: plan)
    @trail_world = helpers.trail_mountain_world_locals(
      trail: trail,
      goal: @goal,
      plan: plan,
      journey: @journey,
      destination_overlay: @trail_destination_overlay,
      plans: @plans || []
    )
    now_summit = @trail_world[:summit_reached]
    @trail_summit_state_flipped = (was_summit != now_summit)
    return unless @trail_summit_state_flipped

    projects = @trail_world[:projects]
    all_projects = helpers.mountain_trail_all_projects(trail)
    base_due = helpers.mountain_trail_base_due_battles(projects)
    root_goal = @goal
    all_today =
      if root_goal.present?
        Strategy::Progress.battles_under(root_goal).select { |battle| battle.scheduled_on == Date.current }
      else
        []
      end
    won_today = all_today.count { |battle| battle.completed_at.present? }
    @today_card = helpers.mountain_trail_dock_card(
      projects: projects,
      open_battles: base_due,
      won_today: won_today,
      journey: @journey,
      user: current_user
    )

    camps_done = helpers.mountain_trail_camps_done(all_projects)
    summit_glow = camps_done.to_f / [ all_projects.size, 1 ].max
    @trail_root_attrs = {
      summit_reached: now_summit,
      dormant: helpers.mountain_trail_dormant?(projects),
      summit_glow: (0.16 + summit_glow * 0.5).round(3),
      climb_frac: helpers.mountain_trail_climb_fraction(all_projects).round(3),
      trail_energy: helpers.mountain_trail_energy(projects).round(3)
    }
  end
end
