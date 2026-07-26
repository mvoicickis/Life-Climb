require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "display_name prefers name over email" do
    user = users(:one)
    user.update!(name: "Mareks")
    assert_equal "Mareks", user.display_name

    user.update!(name: nil)
    assert_equal "One", user.display_name
  end

  test "character defaults to man until chosen" do
    user = users(:one)
    assert_nil user.character
    assert_equal "man", user.character_key
    assert_equal "characters/character-man.png", user.character_image
    refute user.character_chosen?
  end

  test "overall closer percent averages life areas" do
    user = users(:one)
    areas = user.active_dream.life_areas.tree.to_a
    skip "needs life areas" if areas.empty?

    areas.each { |a| a.update!(closer_score: 3) } # 50% closer
    assert_equal 50, user.overall_closer_percent(areas)
    assert_equal 50, user.overall_gap_percent(areas)
  end
end
