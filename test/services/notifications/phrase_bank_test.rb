# frozen_string_literal: true

require "test_helper"

module Notifications
  class PhraseBankTest < ActiveSupport::TestCase
    CATEGORIES = Onboarding::Categories::IDS

    test "win and stuck pools have six distinct phrases per category" do
      %w[win stuck].each do |kind|
        CATEGORIES.each do |category|
          phrases = PhraseBank.phrases_for(kind: kind, category: category, locale: :en)
          assert_equal 6, phrases.size, "#{kind}/#{category}"
          assert_equal 6, phrases.uniq.size, "#{kind}/#{category} should be distinct"
          phrases.each do |phrase|
            assert phrase.present?
            refute_match(/\A[🏔️👋☀️]/, phrase)
          end
        end
      end
    end

    test "body_for prefixes win and stuck and picks from pool" do
      pool = PhraseBank.phrases_for(kind: "win", category: "self", locale: :en)
      seen = []

      40.times do
        body = PhraseBank.body_for(kind: "win", category: "self", locale: :en)
        assert body.start_with?("🏔️ ")
        text = body.delete_prefix("🏔️ ")
        assert_includes pool, text
        seen << text
      end

      assert_operator seen.uniq.size, :>=, 2, "random sample should reach more than one phrase"
    end

    test "stuck body uses wave prefix" do
      body = PhraseBank.body_for(kind: "stuck", category: "career", locale: :en)
      assert body.start_with?("👋 ")
      pool = PhraseBank.phrases_for(kind: "stuck", category: "career", locale: :en)
      assert_includes pool, body.delete_prefix("👋 ")
    end

    test "invalid category falls back to other" do
      assert_equal "other", PhraseBank.normalize_category("not-a-category")
      other_pool = PhraseBank.phrases_for(kind: "win", category: "other", locale: :en)
      body = PhraseBank.body_for(kind: "win", category: "bogus", locale: :en)
      assert_includes other_pool, body.delete_prefix("🏔️ ")
    end

    test "locale uses translated strings" do
      en = PhraseBank.phrases_for(kind: "win", category: "self", locale: :en)
      de = PhraseBank.phrases_for(kind: "win", category: "self", locale: :de)
      assert_equal 6, de.size
      refute_equal en, de
      assert de[0].present?
      refute_equal en[0], de[0]
    end

    test "morning_nudge phrases exist for later PR5" do
      I18n.with_locale(:en) do
        phrases = (0..5).map { |i| I18n.t("notifications.morning_nudge.#{i}") }
        assert_equal 6, phrases.uniq.size
      end

      body = PhraseBank.morning_nudge(locale: :en)
      assert body.start_with?("☀️ ")
    end

    test "all six indexes are reachable via sample" do
      pool = PhraseBank.phrases_for(kind: "stuck", category: "money", locale: :en)
      seen = {}

      200.times do
        text = PhraseBank.body_for(kind: "stuck", category: "money", locale: :en).delete_prefix("👋 ")
        seen[text] = true
        break if seen.size == 6
      end

      assert_equal pool.sort, seen.keys.sort
    end
  end
end
