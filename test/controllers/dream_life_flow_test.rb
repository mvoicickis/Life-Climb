require "test_helper"

class DreamLifeFlowTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "home shows v2 today battle board" do
    seed_climb!(@user)
    sign_in_as @user
    get dashboard_path
    assert_response :success
    assert_match(/Today|Battle|Action Points|Life Climb/i, response.body)
    assert_select ".lp-dash-nav"
    assert_no_match(/Morale/, response.body)
  end

  test "life area page lets you edit ideal present and goal" do
    seed_climb!(@user)
    sign_in_as @user
    area = life_areas(:one_family)
    get life_area_path(area)
    assert_response :success
    assert_match(/Family/, response.body)

    patch life_area_path(area), params: {
      life_area: { ambition: "Weekly family dinner", present_scene: "Busy weeks", closer_score: 3 },
      goal_title: "Call family weekly"
    }
    assert_redirected_to life_area_path(area)
    area.reload
    assert_equal "Weekly family dinner", area.ambition
    assert_equal "Call family weekly", area.active_goal.title
  end

  test "bumping closer raises score" do
    seed_climb!(@user)
    sign_in_as @user
    area = life_areas(:one_community)
    assert_difference -> { area.reload.closer_score }, 1 do
      post closer_life_area_path(area)
    end
    assert_redirected_to dashboard_path
  end

  test "onboarding interview creates eight tree parts and focus building" do
    user = User.create!(
      name: "Dreamer",
      email_address: "newdream@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      home_stat_count: 6,
      planning_version: 1
    )
    sign_in_as user

    get onboarding_path
    assert_response :success

    patch onboarding_path, params: { step: "intro", onboarding: { dream: "A full life" } }
    assert_redirected_to onboarding_path(step: "part_self")

    patch onboarding_path, params: {
      step: "part_self",
      onboarding: { ambition: "Strong body", present_scene: "Out of shape" }
    }
    assert_redirected_to onboarding_path(step: "part_love")

    patch onboarding_path, params: {
      step: "part_love",
      onboarding: { ambition: "Find a partner", present_scene: "Single", has_partner: "false" }
    }
    assert_redirected_to onboarding_path(step: "part_family")

    %w[family community humanity animals nature physical_world].each do |key|
      patch onboarding_path, params: {
        step: "part_#{key}",
        onboarding: {
          ambition: key == "physical_world" ? "" : "Dream for #{key}",
          skip: (key == "physical_world" ? "true" : nil)
        }.compact
      }
    end
    assert_redirected_to onboarding_path(step: "focus")

    patch onboarding_path, params: { step: "focus", onboarding: { focus_key: "self" } }
    assert_redirected_to onboarding_path(step: "goal")

    patch onboarding_path, params: { step: "goal", onboarding: { goal: "Get fit" } }
    assert_redirected_to onboarding_path(step: "steps")

    patch onboarding_path, params: {
      step: "steps",
      onboarding: { steps: [ "Train", "Eat well", "Sleep" ] }
    }
    assert_redirected_to onboarding_path(step: "building")

    patch onboarding_path, params: { step: "building", onboarding: { building: "Health plan" } }
    assert_redirected_to onboarding_path(step: "today")

    assert_difference -> { user.dreams.count }, 1 do
      patch onboarding_path, params: {
        step: "today",
        onboarding: { actions: [ "Walk 30 min", "Drink water" ] }
      }
    end
    assert_redirected_to dashboard_path
    user.reload
    assert user.onboarding_completed?
    assert_equal 8, user.life_areas.count
    assert_equal "self", user.focus_life_area.key
    assert_equal "Strong body", user.life_areas.find_by(key: "self").ambition
  end
end
