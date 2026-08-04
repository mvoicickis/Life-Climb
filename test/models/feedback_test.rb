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
end
