require "test_helper"

class V2OnboardingFlowTest < ActionDispatch::IntegrationTest
  test "mvp adventure flow: welcome mountain deadline forge today plan route" do
    post registration_url, params: {
      user: {
        name: "Alex",
        email_address: "fresh@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    assert_redirected_to v2_onboarding_path

    follow_redirect!
    assert_response :success
    assert_match(/Welcome to LifePoints/i, response.body)
    assert_match(/Start My Journey/i, response.body)
    assert_match(/Every day becomes a Battle/i, response.body)
    assert_match(/Ready to begin your journey/i, response.body)
    assert_select ".lp-adventure.is-welcome"
    assert_select ".lp-adventure__welcome"
    assert_select ".lp-adventure__sky"
    assert_select ".lp-adventure__spark", 3
    assert_select ".lp-adventure__mountain.is-trail"
    assert_select ".lp-adventure__mountain-art"
    assert_select ".lp-adventure__intro"
    assert_select ".lp-adventure__cta"
    assert_no_match(/lp-adventure__silhouette/, response.body)
    assert_no_match(/Which area|improve first/i, response.body)

    patch v2_onboarding_url(step: "welcome")
    assert_redirected_to v2_onboarding_path(step: "mountain")
    follow_redirect!
    assert_match(/one mountain you want to conquer/i, response.body)
    year = Strategy::YearCycle.target_dec29.year
    assert_match(/December 29, #{year}/i, response.body)

    patch v2_onboarding_url(step: "mountain"), params: {
      onboarding: { title: "Become a Ruby Developer" }
    }
    assert_redirected_to v2_onboarding_path(step: "deadline")
    follow_redirect!
    assert_match(/December 29, #{year}/i, response.body)
    assert_match(/Become a Ruby Developer/i, response.body)

    patch v2_onboarding_url(step: "deadline")
    assert_redirected_to v2_onboarding_path(step: "forge")
    follow_redirect!
    assert_match(/Forging Your Adventure/i, response.body)
    assert_match(/Raising your mountain/i, response.body)
    assert_match(/How the Game Works/i, response.body)

    user = User.find_by!(email_address: "fresh@example.com")
    assert user.onboarding_completed?
    assert user.needs_adventure_guide?
    assert_equal "self", user.life_areas.v2_selected.first.key
    journey = user.primary_focused_journey
    assert_equal "Become a Ruby Developer", journey.title
    assert_equal "pending", journey.setup_flag("route")
    goal = user.strategy_goals.for_kind("goal").roots.first
    assert_equal "Become a Ruby Developer", goal.title
    assert Strategy::YearCycle.dec29?(goal.due_on)
    mission = user.missions.for_day(Date.current).primary.first
    assert_equal "Plan Your Route", mission.title
    assert_equal 25, mission.lp_reward
    assert_operator user.strategy_points, :>=, 100

    get dashboard_path
    assert_redirected_to v2_onboarding_path(step: "how")

    get v2_onboarding_path(step: "how")
    assert_response :success
    assert_match(/How the game works/i, response.body)
    assert_match(/Find a job/i, response.body)
    assert_match(/Polish resume/i, response.body)
    assert_match(/Write 5 strong bullets/i, response.body)
    assert_match(/Claim Trail Guide badge/i, response.body)
    assert_select "[data-controller='adventure-guide']"
    assert_select ".lp-adventure__how-stage"
    assert_select ".lp-adventure__how-titlecard"
    assert_select ".lp-adventure__how-dots li", 4
    assert_select ".lp-adventure__how-flag", 4
    assert_select ".lp-adventure__how-map-node", 4
    assert_select ".lp-adventure__how-badge"

    patch v2_onboarding_url(step: "how")
    assert_redirected_to dashboard_path
    user.reload
    assert user.adventure_guide_done?
    assert_not user.needs_adventure_guide?

    get dashboard_path
    assert_response :success
    assert_match(/Become a Ruby Developer/i, response.body)
    assert_match(/Plan Your Route/i, response.body)
    assert_match(/Build Strategy/i, response.body)
    assert_match(/Year Adventure/i, response.body)
    assert_no_match(/Complete Today.?s Battle/i, response.body)

    achievements = Progress::Dashboard.call(user: user, period: "7d")[:achievements]
    guide = achievements.find { |a| a[:key] == "adventure_guide" }
    assert guide
    assert guide[:unlocked]
    assert_match(/Trail Guide/i, guide[:title])
  end

  test "plan route mission retires after first strategy battle exists" do
    post registration_url, params: {
      user: {
        name: "Sam",
        email_address: "route@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    patch v2_onboarding_url(step: "welcome")
    patch v2_onboarding_url(step: "mountain"), params: { onboarding: { title: "Ship LifePoints" } }
    patch v2_onboarding_url(step: "deadline")
    patch v2_onboarding_url(step: "how")

    user = User.find_by!(email_address: "route@example.com")
    journey = user.primary_focused_journey
    area = journey.life_area
    goal = user.strategy_goals.for_kind("goal").roots.first
    plan = user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: goal, horizon: "plan", title: "Build", position: 0
    )
    project = user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: plan, horizon: "project", title: "Launch", position: 0
    )
    user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: project, horizon: "day",
      title: "Write one test", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: user, life_area: area)

    get dashboard_path
    assert_response :success
    assert_no_match(/Plan Your Route/i, response.body)
    assert_no_match(/Build Strategy/i, response.body)
    assert_match(/Write one test/i, response.body)
    assert_equal "done", journey.reload.setup_flag("route")
  end

  test "completing a journey opens next mountain choice" do
    user = users(:one)
    sign_in_as user
    Onboarding::Run.call(
      user: user,
      area_key: "learning",
      title: "Learn Rails",
      ideal_scene: "Fluent Rails",
      current_reality: "Beginner",
      next_win: "Finish the first course",
      today_mission: "Complete one lesson",
      closer_percent: 20
    )
    journey = user.primary_focused_journey

    post life_journey_completion_url(journey)
    assert_redirected_to next_mountain_path
    follow_redirect!
    assert_match(/Congratulations|next/i, response.body)
  end
end
