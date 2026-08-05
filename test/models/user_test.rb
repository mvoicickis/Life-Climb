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

  test "character helpers signal no companion until one of the five is chosen" do
    user = users(:one)
    assert_nil user.character
    assert_nil user.character_key
    assert_nil user.character_image
    refute user.character_chosen?
    assert user.needs_companion_pick?

    user.update!(character: "fox")
    assert_equal "fox", user.character_key
    assert_equal "characters/character-fox.png", user.character_image
    assert user.character_chosen?
    refute user.needs_companion_pick?
  end

  test "character validation accepts only the five companions" do
    user = users(:one)
    User::CHARACTERS.each do |key|
      user.character = key
      assert user.valid?, "#{key} should be valid"
    end

    user.character = "dragon"
    refute user.valid?
    assert_includes user.errors[:character], "is not included in the list"
  end

  test "legacy man or woman keeps working until re-pick without blocking other updates" do
    user = users(:one)
    user.update_columns(character: "woman", onboarding_completed_at: Time.current, planning_version: 2)
    refute user.character_chosen?
    assert user.legacy_character?
    assert user.needs_companion_pick?

    assert user.update(name: "Still Valid")
    assert_equal "woman", user.reload.character
  end

  test "theme defaults to light and rejects unknown values" do
    user = users(:one)
    assert_equal "light", user.theme
    assert_equal "light", user.theme_key

    user.theme = "dark"
    assert user.valid?

    user.theme = "neon"
    refute user.valid?
    assert_includes user.errors[:theme], "is not included in the list"
  end

  test "overall closer percent averages life areas for legacy v1" do
    user = users(:one)
    user.update!(planning_version: 1)
    areas = user.active_dream.life_areas.tree.to_a
    skip "needs life areas" if areas.empty?

    areas.each { |a| a.update!(closer_score: 3) } # 50% closer
    assert_equal 50, user.overall_closer_percent(areas)
    assert_equal 50, user.overall_gap_percent(areas)
  end

  test "overall closer percent uses journey gap for planning v2" do
    user = users(:one)
    seed_climb!(user)
    # Empty gap when the climb is just started → closer stays high until progress math moves.
    assert_equal (100 - user.overall_gap_percent).clamp(0, 100), user.overall_closer_percent
  end
end
