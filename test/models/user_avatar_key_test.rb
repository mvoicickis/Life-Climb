# frozen_string_literal: true

require "test_helper"

class UserAvatarKeyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "accepts the four animal keys" do
    User::AVATAR_KEYS.each do |key|
      @user.avatar_key = key
      assert @user.valid?, "expected #{key} to be valid: #{@user.errors.full_messages}"
      assert_equal "avatars/#{key}.webp", @user.avatar_image
    end
  end

  test "rejects junk keys" do
    @user.avatar_key = "dragon"
    refute @user.valid?
    assert_includes @user.errors[:avatar_key], "is not included in the list"
  end

  test "blank avatar_key becomes nil" do
    @user.update!(avatar_key: "fox")
    @user.avatar_key = ""
    assert @user.valid?
    @user.save!
    assert_nil @user.reload.avatar_key
    assert_nil @user.avatar_image
  end
end
