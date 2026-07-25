require "test_helper"

class DreamLifeFlowTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "today shows person map and direction" do
    sign_in_as @user
    get dashboard_path
    assert_response :success
    assert_match(/Your dream life/, response.body)
    assert_match(/Are you going the right way/, response.body)
    assert_select ".person-map"
    assert_select ".studio-direction"
    assert_match(/Friends/, response.body)
  end

  test "life area page lets you edit dream and goal" do
    sign_in_as @user
    area = life_areas(:one_self)
    get life_area_path(area)
    assert_response :success
    assert_match(/You/, response.body)

    patch life_area_path(area), params: {
      life_area: { ambition: "Run a marathon" },
      goal_title: "Finish a marathon"
    }
    assert_redirected_to life_area_path(area)
    assert_equal "Run a marathon", area.reload.ambition
    assert_equal "Finish a marathon", area.active_goal.title
  end

  test "onboarding interview creates six parts and focus building" do
    user = User.create!(
      email_address: "newdream@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      home_stat_count: 6
    )
    sign_in_as user

    get onboarding_path
    assert_response :success
    assert_match(/What is your dream life/, response.body)

    patch onboarding_path, params: { step: "intro", onboarding: { dream: "A full life" } }
    assert_redirected_to onboarding_path(step: "part_self")

    patch onboarding_path, params: {
      step: "part_self",
      onboarding: { ambition: "Strong body" }
    }
    assert_redirected_to onboarding_path(step: "part_creativity")

    patch onboarding_path, params: {
      step: "part_creativity",
      onboarding: { ambition: "Find a partner", has_partner: "false" }
    }
    assert_redirected_to onboarding_path(step: "part_group")

    %w[group species life_forms physical_universe].each do |key|
      patch onboarding_path, params: {
        step: "part_#{key}",
        onboarding: { ambition: key == "physical_universe" ? "" : "Dream for #{key}", skip: key == "physical_universe" ? "true" : nil }.compact
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
    assert_equal 6, user.life_areas.count
    assert_equal "self", user.focus_life_area.key
    assert_equal "Strong body", user.life_areas.find_by(key: "self").ambition
  end
end
