require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  test "feedback page shows email contact" do
    sign_in_as users(:one)

    get new_feedback_path
    assert_response :success
    assert_match(/mvoicickis@gmail\.com/, response.body)
    assert_match(/mailto:mvoicickis@gmail\.com/, response.body)
  end

  test "feedback page shows whatsapp when configured" do
    ENV["CONTACT_WHATSAPP"] = "+371 2000 0000"

    sign_in_as users(:one)
    get new_feedback_path

    assert_response :success
    assert_match(%r{https://wa\.me/37120000000}, response.body)
    assert_match(/WhatsApp/, response.body)
  ensure
    ENV.delete("CONTACT_WHATSAPP")
  end

  test "create redirects to contact options" do
    sign_in_as users(:one)

    assert_no_difference "Feedback.count" do
      post feedbacks_path, params: { feedback: { body: "ignored" } }
    end

    assert_redirected_to new_feedback_path
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
