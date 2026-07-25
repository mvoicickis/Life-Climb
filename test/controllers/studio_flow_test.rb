require "test_helper"

class StudioFlowTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "today shows dream goal building story" do
    sign_in_as @user
    get dashboard_path
    assert_response :success
    assert_match(/Work with skill and freedom/, response.body)
    assert_match(/Become a Ruby on Rails developer/, response.body)
    assert_match(/LifePoints/, response.body)
    assert_match(/Finish authentication/, response.body)
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

  test "nav includes building finished and life points" do
    sign_in_as @user
    get dashboard_path
    assert_match(/Building/, response.body)
    assert_match(/Finished/, response.body)
    assert_select "a[href=?]", finished_products_path
    assert_select "a[href=?]", life_points_path
  end
end
