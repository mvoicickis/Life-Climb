# frozen_string_literal: true

require "test_helper"

class FirstTipsHelperTest < ActionView::TestCase
  include FirstTipsHelper

  setup do
    @user = users(:one)
  end

  test "guide avatar url uses You avatar image only" do
    @user.update!(avatar_key: "wolf", character: "fox")

    assert_equal image_path("avatars/wolf.webp"), first_tip_guide_avatar_url(@user)
    assert_nil first_tip_guide_initial(@user)
  end

  test "guide initial matches avatar circle when no avatar image" do
    @user.update!(name: "Hope", avatar_key: nil, character: "fox")

    assert_nil first_tip_guide_avatar_url(@user)
    assert_equal "H", first_tip_guide_initial(@user)
  end
end
