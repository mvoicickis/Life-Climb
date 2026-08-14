# frozen_string_literal: true

# Seeds a v2 player who can reach Today / Mountain without hierarchy redirects.
module ClimbTestHelper
  # Days hang on the path-level camp. Returns +camp+ so existing call sites
  # that create children on the leaf keep working after flatten.
  def practice_leaf_for!(camp, title: "Steps")
    camp
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
    project.children.create!(
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
