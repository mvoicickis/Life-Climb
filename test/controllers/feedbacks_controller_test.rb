require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  test "signed in user can send feedback" do
    user = users(:one)
    sign_in_as user

    assert_difference "Feedback.count", 1 do
      post feedbacks_path, params: { feedback: { body: "Love the Today board." } }
    end

    assert_redirected_to dashboard_path
    feedback = Feedback.last
    assert_equal user, feedback.user
    assert_equal "Love the Today board.", feedback.body
  end

  test "rejects blank feedback" do
    sign_in_as users(:one)
    assert_no_difference "Feedback.count" do
      post feedbacks_path, params: { feedback: { body: "" } }
    end
    assert_response :unprocessable_entity
  end
end

class AdminDashboardTest < ActionDispatch::IntegrationTest
  test "admin can open admin dashboard" do
    sign_in_as users(:admin)
    get admin_root_path
    assert_response :success
    assert_match(/Users/, response.body)
    assert_match(/Feedback/, response.body)
  end

  test "non admin cannot open admin dashboard" do
    sign_in_as users(:one)
    get admin_root_path
    assert_redirected_to dashboard_path
  end
end
