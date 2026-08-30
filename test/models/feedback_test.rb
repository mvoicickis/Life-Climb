# frozen_string_literal: true

require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  test "requires body and accepts optional rating and page context" do
    feedback = Feedback.new(body: "Hi", rating: 5, page_context: " today ")
    assert feedback.valid?
    feedback.save!
    assert_equal "today", feedback.page_context

    blank = Feedback.new(body: "")
    assert_not blank.valid?
  end

  test "user is optional for anonymous testers" do
    feedback = Feedback.create!(body: "From landing", page_context: "landing", rating: 3)
    assert_nil feedback.user_id
  end

  test "normalizes app_version" do
    feedback = Feedback.new(body: "Hi", app_version: " abc1234 ")
    assert feedback.valid?
    feedback.save!
    assert_equal "abc1234", feedback.app_version
  end

  test "contact_info is cleared unless ok_to_contact" do
    feedback = Feedback.create!(
      body: "Please ignore this number",
      ok_to_contact: false,
      contact_info: "+1000000"
    )
    assert_equal false, feedback.ok_to_contact
    assert_nil feedback.contact_info

    feedback.update!(ok_to_contact: true, contact_info: " me@example.com ")
    assert_equal "me@example.com", feedback.contact_info
  end
end
