require "test_helper"

class DreamLifeFlowTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "home shows calm dream hero tree and quest" do
    sign_in_as @user
    get dashboard_path
    assert_response :success
    assert_match(/Dream Life/, response.body)
    assert_match(/Today.s Quest|Today&#39;s Quest/, response.body)
    assert_select ".lp-dream-hero"
    assert_select ".lp-tree"
    assert_select ".lp-quest"
    assert_match(/Life Points/, response.body)
    assert_no_match(/Morale/, response.body)
  end

  test "life area page lets you edit ideal present and goal" do
    sign_in_as @user
    area = life_areas(:one_family)
    get life_area_path(area)
    assert_response :success
    assert_match(/Family/, response.body)
    assert_match(/Ideal/, response.body)
    assert_match(/Present/, response.body)

    patch life_area_path(area), params: {
      life_area: { ambition: "Weekly family dinner", present_scene: "Busy weeks", closer_score: 3 },
      goal_title: "Call family weekly"
    }
    assert_redirected_to life_area_path(area)
    area.reload
    assert_equal "Weekly family dinner", area.ambition
    assert_equal "Busy weeks", area.present_scene
    assert_equal 3, area.closer_score
    assert_equal "Call family weekly", area.active_goal.title
  end

  test "bumping closer raises score" do
    sign_in_as @user
    area = life_areas(:one_community)
    assert_difference -> { area.reload.closer_score }, 1 do
      post closer_life_area_path(area)
    end
    assert_redirected_to dashboard_path
  end

  test "onboarding interview creates seven tree parts and focus building" do
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

    patch onboarding_path, params: { step: "focus", onboarding: { focus_key: "love" } }
    assert_redirected_to onboarding_path(step: "goal")

    patch onboarding_path, params: { step: "goal", onboarding: { goal: "Grow love" } }
    assert_redirected_to onboarding_path(step: "steps")

    patch onboarding_path, params: {
      step: "steps",
      onboarding: { steps: [ "Listen", "Show up", "Plan dates" ] }
    }
    assert_redirected_to onboarding_path(step: "building")

    patch onboarding_path, params: { step: "building", onboarding: { building: "Love plan" } }
    assert_redirected_to onboarding_path(step: "today")

    assert_difference -> { user.dreams.count }, 1 do
      patch onboarding_path, params: {
        step: "today",
        onboarding: { actions: [ "Send a kind message", "Walk together" ] }
      }
    end
    assert_redirected_to dashboard_path
    user.reload
    assert user.onboarding_completed?
    assert_equal 7, user.life_areas.count
    assert_equal "love", user.focus_life_area.key
    assert_equal "Find a partner", user.life_areas.find_by(key: "love").ambition
  end
end
