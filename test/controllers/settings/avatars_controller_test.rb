# frozen_string_literal: true

require "test_helper"

module Settings
  class AvatarsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @other = users(:two)
      seed_climb!(@user)
      sign_in_as @user
    end

    test "You shows letter circle when avatar_key is blank" do
      @user.update!(avatar_key: nil)
      get settings_path

      assert_response :success
      assert_select "#you-avatar-circle .lp-avatar-circle--initial", text: "O"
      assert_select "#you-avatar-circle img", count: 0
      assert_select "#avatar-picker-sheet-title", text: "Pick your animal"
    end

    test "update saves animal and turbo stream replaces the circle" do
      assert_nil @user.avatar_key

      patch settings_avatar_path,
            params: { user: { avatar_key: "fox" } },
            as: :turbo_stream

      assert_response :success
      assert_equal "fox", @user.reload.avatar_key
      assert_match(/turbo-stream[^>]*action="replace"[^>]*target="you-avatar"/, response.body)
      assert_match(%r{avatars/fox[^"]*}, response.body)
      assert_includes response.body, "lp-avatar-circle is-lg"
      assert_includes response.body, "lp-you-avatar is-lg"
      refute_includes response.body, "lp-avatar-circle--initial"
    end

    test "You shows animal after save" do
      @user.update!(avatar_key: "bear")
      get settings_path

      assert_response :success
      assert_select "#you-avatar.lp-you-avatar.is-lg"
      assert_select "#you-avatar-circle img.lp-avatar-circle.is-lg[src*='bear']"
      assert_select "#you-avatar-circle .lp-avatar-circle--initial", count: 0
      assert_select ".avatar-picker-sheet__item.is-selected img[src*='bear']"
    end

    test "Use my letter clears avatar_key" do
      @user.update!(avatar_key: "wolf")

      patch settings_avatar_path,
            params: { user: { avatar_key: "" } },
            as: :turbo_stream

      assert_response :success
      assert_nil @user.reload.avatar_key
      assert_includes response.body, "lp-avatar-circle--initial"
      assert_includes response.body, "is-lg"
    end

    test "another user cannot change yours" do
      @user.update!(avatar_key: "bird")
      sign_out
      seed_climb!(@other, area_key: "self", today_mission: "Other battle")
      sign_in_as @other

      patch settings_avatar_path,
            params: { user: { avatar_key: "fox" } },
            as: :turbo_stream

      assert_response :success
      assert_equal "fox", @other.reload.avatar_key
      assert_equal "bird", @user.reload.avatar_key
    end

    test "rejects invalid avatar_key" do
      patch settings_avatar_path,
            params: { user: { avatar_key: "dragon" } },
            as: :turbo_stream

      assert_response :unprocessable_entity
      assert_nil @user.reload.avatar_key
    end
  end
end
