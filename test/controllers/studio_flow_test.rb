require "test_helper"

class StudioFlowTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "today shows calm home with quest" do
    sign_in_as @user
    get dashboard_path
    assert_response :success
    assert_match(/Overall Gap/, response.body)
    assert_match(/Life Points/, response.body)
    assert_match(/Finish authentication/, response.body)
    assert_select ".lp-twin"
    assert_select ".lp-map-card"
    assert_select ".lp-mission"
  end

  test "completing today action earns life points" do
    sign_in_as @user
    action = today_actions(:one)
    action.update!(completed_at: nil)

    assert_difference -> { @user.reload.total_points }, LifePointsAward::ACTION do
      post complete_today_action_path(action)
    end
    assert_redirected_to dashboard_path
  end

  test "life points page shows alive story" do
    sign_in_as @user
    get life_points_path
    assert_response :success
    assert_match(/more alive you are/, response.body)
  end

  test "nav includes plan finished and life points" do
    sign_in_as @user
    get dashboard_path
    assert_match(/Plan/, response.body)
    assert_match(/Finished/, response.body)
    assert_select "a[href=?]", finished_products_path
    assert_select "a[href=?]", life_points_path
  end

  test "building page loads focus building" do
    sign_in_as @user
    get building_path
    assert_response :success
    assert_match(/LifePoints/, response.body)
  end
end
