# frozen_string_literal: true

module RequireOnboarding
  extend ActiveSupport::Concern

  included do
    before_action :redirect_to_onboarding_if_needed
  end

  class_methods do
    def skip_onboarding_check(**options)
      skip_before_action :redirect_to_onboarding_if_needed, **options
    end
  end

  private

  def redirect_to_onboarding_if_needed
    return unless authenticated?
    return if onboarding_flow_controller?

    current_user.update!(planning_version: 2) if current_user && !current_user.planning_v2? && !impersonating?
    if current_user&.needs_onboarding?
      redirect_to v2_onboarding_path and return
    end

    # How-guide is optional after forge — never block Today / Mountain / Journey.
    redirect_to_strategy_if_hierarchy_incomplete
  end

  def redirect_to_strategy_if_hierarchy_incomplete
    return if hierarchy_gate_exempt?
    return if Strategy::HierarchyReady.call(user: current_user)

    journey = current_user.primary_focused_journey || current_user.life_journeys.active.order(:id).first
    if journey
      redirect_to life_journey_path(journey), notice: I18n.t("strategy.hierarchy_gate.notice")
    else
      redirect_to new_life_journey_path
    end
  end

  def onboarding_flow_controller?
    %w[onboarding sessions registrations passwords v2_onboardings life_area_selections next_mountains two_factor_sessions].include?(controller_name)
  end

  def hierarchy_gate_exempt?
    return true if controller_path.start_with?("admin", "developer", "settings")

    # Today stays reachable: empty / plan-route / handoff states guide players to Mountain.
    # Completing Today actions must not bounce mid-fight when the spine is still growing.
    %w[
      dashboard
      quick_battles
      today_commitments
      battle_completions
      daily_todos
      mission_completions
      life_journeys
      strategy_goals
      strategy_goal_completions
      first_climbs
      life_journey_plant_destinations
      companion_guides
      weekly_planners
      strategy_helps
      journey_completions
      journey_targets
      project_completions
      battle_wins
      battle_reopens
      strategy_quantity_logs
      strategy_goal_restores
      mountain_trail_tours
      onboarding_mountain_tours
      settings
      push_subscriptions
      push_configs
      two_factors
      two_factor_sessions
      locales
      feedbacks
      supports
      abouts
      pricing
      life_points
      progress
      focus
      pages
      finished_products
      buildings
      today_actions
      areas
      habits
      habit_improvement_projects
      strategy_goal_habit_links
    ].include?(controller_name)
  end
end
