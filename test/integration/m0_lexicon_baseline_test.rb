# frozen_string_literal: true

require "test_helper"

# M0 — Lexicon + Screen Ownership Baseline
class M0LexiconBaselineTest < ActiveSupport::TestCase
  test "foundation docs exist" do
    %w[DECISIONS.md ENGINEERING.md LEXICON.md ROADMAP.md].each do |name|
      path = Rails.root.join("docs", name)
      assert File.exist?(path), "missing docs/#{name}"
      assert File.size(path).positive?, "docs/#{name} is empty"
    end
  end

  test "pull request template includes ownership and decisions gates" do
    template = Rails.root.join(".github/PULL_REQUEST_TEMPLATE.md").read
    assert_includes template, "Which screen owns this?"
    assert_includes template, "docs/DECISIONS.md"
    assert_includes template, "One Battle Plan Law"
  end

  test "primary nav uses player lexicon" do
    I18n.with_locale(:en) do
      assert_equal "Mountain", I18n.t("dash.nav.mountain")
      assert_equal "Today", I18n.t("dash.nav.today")
      assert_equal "Journey", I18n.t("dash.nav.journey")
      assert_equal "You", I18n.t("dash.nav.you")
      assert_equal "Journey", I18n.t("progress.title")
    end
  end

  test "lexicon hotspot keys still exist for fix-as-you-touch" do
    I18n.with_locale(:en) do
      {
        "strategy.rpg.plans_kicker" => /plan/i,
        "strategy.rpg.add_plan" => /plan/i,
        "strategy.next_up.enter_plan_cta" => /plan/i,
        "strategy.horizons.plan" => /plan/i,
        "strategy.levels.plan" => /plan/i,
        "strategy.zones.add_plan_hint" => /plan/i
      }.each do |key, pattern|
        assert I18n.exists?(key), "hotspot locale missing: #{key}"
        assert_match pattern, I18n.t(key), "#{key} should still show Plan wording until a later milestone fixes it"
      end
    end
  end
end
