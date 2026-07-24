require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "signed in user can send feedback" do
    user = users(:one)
    sign_in_as user

    assert_emails 1 do
      assert_difference "Feedback.count", 1 do
        post feedbacks_path, params: { feedback: { body: "Love the Today board." } }
      end
    end

    assert_redirected_to dashboard_path
    feedback = Feedback.last
    assert_equal user, feedback.user
    assert_equal "Love the Today board.", feedback.body

    email = ActionMailer::Base.deliveries.last
    assert_equal [ "mvoicickis@gmail.com" ], email.to
    assert_equal user.email_address, email.reply_to.first
    assert_match "Love the Today board.", email.body.encoded
  end

  test "rejects blank feedback" do
    sign_in_as users(:one)
    assert_no_difference "Feedback.count" do
      assert_no_emails do
        post feedbacks_path, params: { feedback: { body: "" } }
      end
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
