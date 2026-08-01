# frozen_string_literal: true

# Seeds a v2 player who can reach Today / Mountain without hierarchy redirects.
module ClimbTestHelper
  # Days hang under nested camps. Returns +camp+ when already nested; otherwise
  # creates (or reuses) a "Steps" leaf under a Path-level camp.
  def practice_leaf_for!(camp, title: "Steps")
    return camp if camp.project? && camp.parent&.project?

    existing = camp.children.find { |child| child.project? && child.title == title }
    return existing if existing

    camp.children.create!(
      user: camp.user,
      life_area: camp.life_area,
      life_journey: camp.life_journey,
      horizon: "project",
      title: title,
      position: camp.children.maximum(:position).to_i
    )
  end

  def seed_climb!(
    user,
    area_key: "career",
    title: "Ship LifePoints",
    today_mission: "Finish authentication"
  )
    Onboarding::Run.call(
      user: user,
      area_key: area_key,
      title: title,
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: today_mission,
      closer_percent: 20,
      route_mission: true
    )
    user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    journey = user.reload.primary_focused_journey
    goal = user.strategy_goals.for_kind("goal").roots.first
    plan = goal.children.create!(
      user: user, life_area: journey.life_area, life_journey: journey,
      horizon: "plan", title: "Build", position: 0
    )
    project = plan.children.create!(
      user: user, life_area: journey.life_area, life_journey: journey,
      horizon: "project", title: "Auth", position: 0
    )
    nested = project.children.create!(
      user: user, life_area: journey.life_area, life_journey: journey,
      horizon: "project", title: "First steps", position: 0
    )
    nested.children.create!(
      user: user, life_area: journey.life_area, life_journey: journey,
      horizon: "day", title: today_mission, scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: user, life_area: journey.life_area)
    journey
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include ClimbTestHelper
end
