# frozen_string_literal: true

require "test_helper"

class Strategy::NextAction::CopyTest < ActiveSupport::TestCase
  KEYS = Strategy::NextAction::Copy::KEYS
  PREFIXES = Strategy::NextAction::Copy::PREFIXES

  test "each state has four distinct titles" do
    KEYS.each do |key|
      phrases = Strategy::NextAction::Copy.phrases_for(key: key, locale: :en)
      assert_equal 4, phrases.size, "#{key} size"
      assert_equal 4, phrases.uniq.size, "#{key} should be distinct"
      phrases.each do |phrase|
        assert phrase.present?
        refute_match(/\A[🧭📍⚔️🏕️🏁]/, phrase)
      end
    end
  end

  test "headline_for prefixes the correct emoji and picks from pool" do
    KEYS.each do |key|
      pool = Strategy::NextAction::Copy.phrases_for(key: key, locale: :en)
      prefix = PREFIXES.fetch(key)
      title = %i[complete_battle confirm_camp].include?(key) ? "Ship it" : nil
      seen = []

      40.times do
        headline = Strategy::NextAction::Copy.headline_for(key: key, title: title, locale: :en)
        assert headline.start_with?(prefix), "#{key} missing #{prefix.inspect} in #{headline.inspect}"
        text = headline.delete_prefix(prefix)
        expected_pool =
          if title
            pool.map { |p| I18n.interpolate(p, title: title) }
          else
            pool
          end
        assert_includes expected_pool, text
        seen << text
      end

      assert_operator seen.uniq.size, :>=, 2, "#{key} sample should reach more than one phrase"
    end
  end

  test "complete_battle and confirm_camp interpolate title" do
    battle = Strategy::NextAction::Copy.headline_for(key: :complete_battle, title: "Send five emails", locale: :en)
    assert_includes battle, "Send five emails"
    assert battle.start_with?("⚔️ ")

    camp = Strategy::NextAction::Copy.headline_for(key: :confirm_camp, title: "Improve apps", locale: :en)
    assert_includes camp, "Improve apps"
    assert camp.start_with?("🏕️ ")
  end
end
