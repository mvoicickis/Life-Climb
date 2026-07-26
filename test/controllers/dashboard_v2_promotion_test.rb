require "test_helper"

class DashboardV2PromotionTest < ActionDispatch::IntegrationTest
  test "legacy planning_version 1 users are promoted off the Life Tree Home" do
    user = users(:one)
    user.update_columns(planning_version: 1, onboarding_completed_at: Time.current)

    # Give them a focused v2 journey so Home can render after promotion.
    Onboarding::Run.call(
      user: user,
      area_key: "money",
      title: "Financial freedom",
      ideal_scene: "Calm money life",
      current_reality: "Still budgeting",
      next_win: "Save first €100",
      today_mission: "Review budget",
      closer_percent: 20
    )
    user.update_columns(planning_version: 1)

    sign_in_as user
    get dashboard_path
    assert_response :success
    user.reload
    assert_equal 2, user.planning_version
    assert_match(/lp-dash/i, response.body)
    assert_no_match(/lp-tree|Life Tree/i, response.body)
  end
end
