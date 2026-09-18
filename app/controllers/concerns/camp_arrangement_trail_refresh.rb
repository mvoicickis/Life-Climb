# frozen_string_literal: true

# Shared Mountain + arrange-overlay turbo locals after camp tree changes.
module CampArrangementTrailRefresh
  extend ActiveSupport::Concern
  include MountainSheetRefresh

  private

  def assign_camp_arrangement_trail_refresh!(plan:, journey:, arrange_overlay_open: false,
                                               destination_overlay: false, first_camp_reveal: false)
    @plan = plan.reload
    @journey = journey
    @goal = @plan.root_goal
    @trail = Strategy::Trail.for(plan: @plan)
    all_projects = helpers.mountain_trail_all_projects(@trail)
    @arrange_projects = all_projects
    @projects = helpers.mountain_trail_projects(@trail)
    @current_project = helpers.mountain_trail_current_project(@projects)
    assign_mountain_climber_context!

    base_due_battles = helpers.mountain_trail_base_due_battles(@projects)
    root = @goal
    all_today = root.present? ? Strategy::Progress.battles_under(root).select { |b| b.scheduled_on == Date.current } : []
    won_today = all_today.count { |b| b.completed_at.present? }
    @today_card = helpers.mountain_trail_dock_card(
      projects: @projects,
      open_battles: base_due_battles,
      won_today: won_today,
      journey: @journey
    )

    @show_arrange_camps = helpers.mountain_trail_show_arrange_camps?(
      trail: @trail,
      plan: @plan,
      destination_overlay: destination_overlay,
      first_camp_reveal: first_camp_reveal
    )
    @arrange_overlay_open = arrange_overlay_open && @show_arrange_camps
    @open_stage = helpers.mountain_trail_open_stage(@arrange_projects)
  end
end
