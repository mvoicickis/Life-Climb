require "test_helper"

class V2OnboardingFlowTest < ActionDispatch::IntegrationTest
  test "mvp adventure flow: welcome category mountain deadline forge today plan route" do
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
    assert_match(/See My First Step/i, response.body)
    assert_match(/Takes about 2 minutes/i, response.body)
    assert_match(/One goal becomes your mountain/i, response.body)
    assert_match(/Ready to name your goal/i, response.body)
    assert_select ".lp-adventure.is-welcome"
    assert_select ".lp-adventure__welcome"
    assert_select ".lp-adventure__sky"
    assert_select ".lp-adventure__spark", 3
    assert_select ".lp-adventure__mountain.is-trail"
    assert_select ".lp-adventure__mountain-art"
    assert_select ".lp-adventure__intro"
    assert_select ".lp-adventure__cta"
    assert_no_match(/lp-adventure__silhouette/, response.body)

    patch v2_onboarding_url(step: "welcome")
    assert_redirected_to v2_onboarding_path(step: "character")
    follow_redirect!
    assert_match(/Choose your companion/i, response.body)
    assert_match(/Step 2 of 5/i, response.body)
    assert_select "input[name='user[character]'][value=birdie]"
    assert_select "input[name='user[character]'][value=bee]"
    assert_select "input[name='user[character]'][value=bear]"
    assert_select "input[name='user[character]'][value=fox]"
    assert_select "input[name='user[character]'][value=horse]"
    assert_select "img[src*='character-fox']"
    assert_select "a.lp-adventure__back[href=?]", v2_onboarding_path(step: "welcome"), text: /Back/i
    assert_select ".lp-adventure__progress-track"

    patch v2_onboarding_url(step: "character"), params: { user: { character: "fox" } }
    assert_redirected_to v2_onboarding_path(step: "category")
    follow_redirect!
    assert_match(/Where should this climb begin/i, response.body)
    assert_match(/Step 3 of 5/i, response.body)
    assert_select ".lp-adventure__categories"
    assert_select "form[data-controller='onboarding-category']" do
      assert_select "input[type=submit]", count: 0
      assert_select ".lp-adventure__category[data-action*='onboarding-category#pick']", 6
    end
    assert_select "input[name='onboarding[category]'][value=self]"
    assert_select "input[name='onboarding[category]'][value=career]"
    assert_select "input[name='onboarding[category]'][value=money]"
    assert_select "input[name='onboarding[category]'][value=relationships]"
    assert_select "input[name='onboarding[category]'][value=growth]"
    assert_select "input[name='onboarding[category]'][value=other]"
    assert_select "a.lp-adventure__back[href=?]", v2_onboarding_path(step: "character"), text: /Back/i

    patch v2_onboarding_url(step: "category"), params: { onboarding: { category: "career" } }
    assert_redirected_to v2_onboarding_path(step: "mountain")
    follow_redirect!
    assert_match(/one goal you.?re working toward/i, response.body)
    assert_match(/Step 4 of 5/i, response.body)
    assert_select "a.lp-adventure__back[href=?]", v2_onboarding_path(step: "category"), text: /Back/i
    assert_select ".lp-adventure__progress-track"
    assert_select ".lp-adventure__picked", text: /Career/i
    assert_select ".lp-adventure__picked-icon"
    assert_match(/Become a licensed plumber/i, response.body)
    due_on = Strategy::YearCycle.default_goal_due
    due_label = I18n.l(due_on, format: :long)

    get v2_onboarding_path(step: "welcome")
    assert_response :success
    assert_match(/Welcome to LifePoints/i, response.body)

    get v2_onboarding_path(step: "mountain")
    assert_response :success
    assert_match(/one goal you.?re working toward/i, response.body)

    patch v2_onboarding_url(step: "mountain"), params: {
      onboarding: { title: "Become a Ruby Developer" }
    }
    assert_redirected_to v2_onboarding_path(step: "deadline")
    follow_redirect!
    assert_match(/Your climb has a soft finish line/i, response.body)
    assert_match(/One year from today/i, response.body)
    assert_match(/#{Regexp.escape(due_label)}/, response.body)
    assert_match(/Become a Ruby Developer/i, response.body)
    assert_match(/Step 5 of 5/i, response.body)
    assert_select "a.lp-adventure__back[href=?]", v2_onboarding_path(step: "mountain"), text: /Back/i
    assert_select ".lp-adventure__progress-track"
    assert_select "form[data-turbo='false']"
    assert_select "[data-controller='onboarding-deadline']"
    assert_select "button[data-action='onboarding-deadline#show']", text: /Change date/i
    assert_select "#onboarding_due_on[type=date][min=?]", Date.current.tomorrow.to_s
    assert_select "#onboarding_due_on[value=?]", due_on.to_s

    get v2_onboarding_path(step: "mountain")
    assert_response :success
    assert_select "#onboarding_title[value=?]", "Become a Ruby Developer"

    get v2_onboarding_path(step: "deadline")
    assert_response :success

    patch v2_onboarding_url(step: "deadline")
    assert_redirected_to v2_onboarding_path(step: "forge")
    follow_redirect!
    assert_match(/Building your climb/i, response.body)
    assert_match(/Setting your goal/i, response.body)
    assert_match(/Start climbing/i, response.body)
    assert_match(/How climbing works/i, response.body)

    user = User.find_by!(email_address: "fresh@example.com")
    assert user.onboarding_completed?
    assert user.adventure_guide_done?
    assert_not user.needs_adventure_guide?
    assert_equal "career", user.life_areas.v2_selected.first.key
    journey = user.primary_focused_journey
    assert_equal "Become a Ruby Developer", journey.title
    assert_equal "pending", journey.setup_flag("route")
    assert_equal "career", journey.setup_flag("onboarding_category")
    goal = user.strategy_goals.for_kind("goal").roots.first
    assert_equal "Become a Ruby Developer", goal.title
    assert_equal due_on, goal.due_on
    mission = user.missions.for_day(Date.current).primary.first
    assert_equal "Plan Your Route", mission.title
    assert_equal 25, mission.lp_reward
    assert_operator user.strategy_points, :>=, 100

    get dashboard_path
    assert_response :success
    assert_match(/Start my climb|Plan Your Route|See your mountain|Battle/i, response.body)

    get life_journey_path(journey)
    assert_response :success
    assert_match(/Become a Ruby Developer/i, response.body)
    assert_select "#first-climb-coach"
    assert_select ".lp-first-climb__chip", text: "Get certified"
    assert_select ".lp-first-climb__chip", text: "Study chapter 1 for 20 minutes"

    get v2_onboarding_path(step: "how")
    assert_response :success
    assert_match(/How climbing works/i, response.body)
    assert_match(/Get healthier/i, response.body)
    assert_select "[data-controller='adventure-guide']"
    assert_select ".lp-adventure__how-badge"

    achievements = Progress::Dashboard.call(user: user, period: "7d")[:achievements]
    guide = achievements.find { |a| a[:key] == "adventure_guide" }
    assert guide
    assert guide[:unlocked]
    assert_match(/Trail Guide/i, guide[:title])
  end

  test "growth and or else both map to purpose but keep distinct example sets" do
    post registration_url, params: {
      user: {
        name: "Pat",
        email_address: "other-cat@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    patch v2_onboarding_url(step: "welcome")
    patch v2_onboarding_url(step: "character"), params: { user: { character: "birdie" } }
    patch v2_onboarding_url(step: "category"), params: { onboarding: { category: "other" } }
    follow_redirect!
    assert_match(/Clear the biggest blocker/i, response.body)
    assert_select ".lp-adventure__picked", text: /Or else/i

    patch v2_onboarding_url(step: "mountain"), params: { onboarding: { title: "Finish the messy garage" } }
    patch v2_onboarding_url(step: "deadline")

    user = User.find_by!(email_address: "other-cat@example.com")
    assert_equal "purpose", user.life_areas.v2_selected.first.key
    journey = user.primary_focused_journey
    assert_equal "other", journey.setup_flag("onboarding_category")

    get life_journey_path(journey)
    assert_response :success
    assert_select ".lp-first-climb__chip", text: "Clear the biggest blocker"
    assert_select ".lp-first-climb__chip", text: "Take the first small step"
    assert_select ".lp-first-climb__chip", text: "Get certified", count: 0
  end

  test "deadline override date persists and invalid dates fall back to one year" do
    post registration_url, params: {
      user: {
        name: "Dana",
        email_address: "due-on@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    patch v2_onboarding_url(step: "welcome")
    patch v2_onboarding_url(step: "character"), params: { user: { character: "fox" } }
    patch v2_onboarding_url(step: "category"), params: { onboarding: { category: "money" } }
    patch v2_onboarding_url(step: "mountain"), params: { onboarding: { title: "Build a cash cushion" } }

    custom_due = Date.current + 200.days
    patch v2_onboarding_url(step: "deadline"), params: { onboarding: { due_on: custom_due.to_s } }
    assert_redirected_to v2_onboarding_path(step: "forge")

    user = User.find_by!(email_address: "due-on@example.com")
    goal = user.strategy_goals.for_kind("goal").roots.first
    assert_equal custom_due, goal.due_on
  end

  test "blank or past due_on falls back to default one year finish line" do
    post registration_url, params: {
      user: {
        name: "Evan",
        email_address: "due-fallback@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    patch v2_onboarding_url(step: "welcome")
    patch v2_onboarding_url(step: "character"), params: { user: { character: "birdie" } }
    patch v2_onboarding_url(step: "category"), params: { onboarding: { category: "self" } }
    patch v2_onboarding_url(step: "mountain"), params: { onboarding: { title: "Sleep better" } }

    patch v2_onboarding_url(step: "deadline"), params: { onboarding: { due_on: Date.current.to_s } }
    user = User.find_by!(email_address: "due-fallback@example.com")
    goal = user.strategy_goals.for_kind("goal").roots.first
    assert_equal Strategy::YearCycle.default_goal_due, goal.due_on
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
    patch v2_onboarding_url(step: "character"), params: { user: { character: "fox" } }
    patch v2_onboarding_url(step: "category"), params: { onboarding: { category: "career" } }
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
    leaf = practice_leaf_for!(project)
    user.strategy_goals.create!(
      life_area: area, life_journey: journey, parent: leaf, horizon: "day",
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

  test "picking birdie during onboarding shows companion avatar on mountain" do
    post registration_url, params: {
      user: {
        name: "Alexa",
        email_address: "birdie-climber@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }
    patch v2_onboarding_url(step: "welcome")
    patch v2_onboarding_url(step: "character"), params: { user: { character: "birdie" } }
    assert_redirected_to v2_onboarding_path(step: "category")

    user = User.find_by!(email_address: "birdie-climber@example.com")
    assert_equal "birdie", user.character
    assert_equal "characters/character-birdie.png", user.character_image

    patch v2_onboarding_url(step: "category"), params: { onboarding: { category: "relationships" } }
    patch v2_onboarding_url(step: "mountain"), params: { onboarding: { title: "Lead with calm" } }
    patch v2_onboarding_url(step: "deadline")
    follow_redirect! # forge
    patch v2_onboarding_url(step: "forge")

    journey = user.reload.primary_focused_journey
    get life_journey_path(journey)
    assert_response :success
    assert_select "#first-climb-coach img.lp-first-climb__climber-img[src*='character-birdie']"

    # After first climb the Mountain HUD avatar uses the character image.
    post first_climbs_path, params: {
      life_journey_id: journey.id,
      plan_title: "Build trust",
      today_action: "Call one friend"
    }
    get life_journey_path(journey)
    assert_response :success
    assert_select ".lp-rpg-avatar img[src*='character-birdie']"

    # Settings can switch climber later.
    patch settings_path, params: { user: { character: "fox" } }
    assert_redirected_to settings_path(highlight: "character")
    assert_equal "fox", user.reload.character

    get life_journey_path(journey)
    assert_response :success
    assert_select ".lp-rpg-avatar img[src*='character-fox']"
  end
end
