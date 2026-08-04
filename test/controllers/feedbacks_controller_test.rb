# frozen_string_literal: true

require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  test "feedback form shows rating page context and free text" do
    sign_in_as users(:one)

    get new_feedback_path(page: "today")
    assert_response :success
    assert_select "form[action=?]", feedbacks_path
    assert_select "input[name='feedback[page_context]'][value=?]", "today"
    assert_select "input[name='feedback[rating]']", count: 5
    assert_select "textarea[name='feedback[body]']"
    assert_select "input[name='feedback[ok_to_contact]']"
    assert_select "input[name='feedback[contact_info]'][value=?]", users(:one).email_address
    assert_select ".lp-feedback-fab", count: 0
  end

  test "create persists feedback with page context and rating" do
    sign_in_as users(:one)

    assert_difference "Feedback.count", 1 do
      post feedbacks_path, params: {
        feedback: {
          body: "The battle list feels clear.",
          rating: 5,
          page_context: "today",
          ok_to_contact: "0"
        }
      }
    end

    feedback = Feedback.order(:id).last
    assert_equal users(:one).id, feedback.user_id
    assert_equal "The battle list feels clear.", feedback.body
    assert_equal 5, feedback.rating
    assert_equal "today", feedback.page_context
    assert_equal false, feedback.ok_to_contact
    assert_nil feedback.contact_info
    assert_redirected_to dashboard_path
  end

  test "logged in contact opt-in keeps email or whatsapp detail" do
    sign_in_as users(:one)

    assert_difference "Feedback.count", 1 do
      post feedbacks_path, params: {
        feedback: {
          body: "Happy to chat about quests.",
          rating: 4,
          page_context: "mountain",
          ok_to_contact: "1",
          contact_info: "+371 2000 0000"
        }
      }
    end

    feedback = Feedback.order(:id).last
    assert feedback.ok_to_contact?
    assert_equal "+371 2000 0000", feedback.contact_info
  end

  test "unchecked opt-in clears contact_info" do
    sign_in_as users(:one)

    post feedbacks_path, params: {
      feedback: {
        body: "No follow-up please.",
        page_context: "today",
        ok_to_contact: "0",
        contact_info: "should-be-cleared@example.com"
      }
    }

    feedback = Feedback.order(:id).last
    assert_equal false, feedback.ok_to_contact
    assert_nil feedback.contact_info
  end

  test "anonymous visitor can submit feedback with page context" do
    assert_difference "Feedback.count", 1 do
      post feedbacks_path, params: {
        feedback: {
          body: "Landing CTA made sense.",
          rating: 4,
          page_context: "landing",
          ok_to_contact: "1",
          contact_info: "visitor@example.com"
        }
      }
    end

    feedback = Feedback.order(:id).last
    assert_nil feedback.user_id
    assert_equal "landing", feedback.page_context
    assert_equal 4, feedback.rating
    assert feedback.ok_to_contact?
    assert_equal "visitor@example.com", feedback.contact_info
    assert_redirected_to root_path
  end

  test "create captures referer path when page_context blank" do
    sign_in_as users(:one)

    assert_difference "Feedback.count", 1 do
      post feedbacks_path,
           params: { feedback: { body: "Came from habits.", rating: 3 } },
           headers: { "HTTP_REFERER" => "http://www.example.com/habits" }
    end

    assert_equal "/habits", Feedback.order(:id).last.page_context
  end

  test "landing and today show feedback entry points" do
    get root_path
    assert_response :success
    assert_select ".lp-feedback-fab"
    assert_select ".lp-feedback-prompt[data-feedback-prompt-page-value=landing]"

    sign_in_as users(:one)
    seed_climb!(users(:one))
    get dashboard_path
    assert_response :success
    assert_select ".lp-feedback-fab"
    assert_select ".lp-feedback-prompt[data-feedback-prompt-page-value=today]"
  end

  test "admin inbox shows page context and rating" do
    user = users(:one)
    Feedback.create!(
      user: user,
      body: "Need clearer quest colors.",
      rating: 2,
      page_context: "mountain",
      ok_to_contact: true,
      contact_info: "+353 87 234 6580"
    )

    sign_in_as users(:admin)
    get admin_feedbacks_path
    assert_response :success
    assert_match(/Need clearer quest colors/, response.body)
    assert_match(/mountain/, response.body)
    assert_match(%r{2/5}, response.body)
    assert_match(/OK to contact/i, response.body)
    assert_match(/\+353 87 234 6580/, response.body)
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
