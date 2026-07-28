# frozen_string_literal: true

require "test_helper"

class InviteShareMessageTest < ActiveSupport::TestCase
  test "builds invite body and full message with landing url" do
    url = "https://lifepoints.onrender.com/?s=lp"
    body = InviteShareMessage.body(landing_url: url)
    full = InviteShareMessage.call(landing_url: url)

    assert_includes body, "climb one mountain"
    assert_includes body, "Action Points"
    assert_includes body, "Finish real work to climb"
    assert_includes body, "Become more alive"
    refute_includes body, url

    assert_includes full, body
    assert_includes full, "Try it:"
    assert_includes full, url
  end
end
