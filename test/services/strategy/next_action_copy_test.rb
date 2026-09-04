# frozen_string_literal: true

require "test_helper"

class Strategy::NextAction::CopyTest < ActiveSupport::TestCase
  KEYS = Strategy::NextAction::Copy::KEYS
  PREFIXES = Strategy::NextAction::Copy::PREFIXES

  INTERPOLATED = %i[
    complete_battle
    battle_overdue
    streak_at_risk
    project_unlocked
    quest_stalled
  ].freeze

  test "each state has four distinct titles" do
    KEYS.each do |key|
      phrases = Strategy::NextAction::Copy.phrases_for(key: key, locale: :en)
      assert_equal 4, phrases.size, "#{key} size"
      assert_equal 4, phrases.uniq.size, "#{key} should be distinct"
      phrases.each do |phrase|
        assert phrase.present?
        refute_match(/\A[🧭📍⚔️🏕️🏁⚠️🔥✨🌑]/, phrase)
      end
    end
  end

  test "headline_for prefixes the correct emoji and picks from pool" do
    KEYS.each do |key|
      pool = Strategy::NextAction::Copy.phrases_for(key: key, locale: :en)
      prefix = PREFIXES.fetch(key)
      title = INTERPOLATED.include?(key) && key != :streak_at_risk ? "Ship it" : nil
      count = key == :streak_at_risk ? 5 : nil
      seen = []

      40.times do
        headline = Strategy::NextAction::Copy.headline_for(
          key: key, title: title, count: count, locale: :en
        )
        assert headline.start_with?(prefix), "#{key} missing #{prefix.inspect} in #{headline.inspect}"
        text = headline.delete_prefix(prefix)
        expected_pool =
          if title || count
            pool.map { |p| I18n.interpolate(p, title: title.to_s, count: count) }
          else
            pool
          end
        assert_includes expected_pool, text
        seen << text
      end

      assert_operator seen.uniq.size, :>=, 2, "#{key} sample should reach more than one phrase"
    end
  end

  test "complete_battle interpolates title" do
    battle = Strategy::NextAction::Copy.headline_for(key: :complete_battle, title: "Send five emails", locale: :en)
    assert_includes battle, "Send five emails"
    assert battle.start_with?("⚔️ ")
  end

  test "signal headlines interpolate title or count" do
    overdue = Strategy::NextAction::Copy.headline_for(key: :battle_overdue, title: "Ship it", locale: :en)
    assert_includes overdue, "Ship it"
    assert overdue.start_with?("⚠️ ")

    phrases = Strategy::NextAction::Copy.phrases_for(key: :battle_overdue, locale: :en)
    refute phrases.any? { |p| p.match?(/hanging overnight|Don’t leave|Don't leave/i) },
           "battle_overdue should not use deficit overnight framing"

    streak = Strategy::NextAction::Copy.headline_for(key: :streak_at_risk, count: 7, locale: :en)
    assert_includes streak, "7"
    assert streak.start_with?("🔥 ")

    unlocked = Strategy::NextAction::Copy.headline_for(key: :project_unlocked, title: "Improve apps", locale: :en)
    assert_includes unlocked, "Improve apps"
    assert unlocked.start_with?("✨ ")

    stalled = Strategy::NextAction::Copy.headline_for(key: :quest_stalled, title: "Checklist", locale: :en)
    assert_includes stalled, "Checklist"
    assert stalled.start_with?("🌑 ")
  end
end
