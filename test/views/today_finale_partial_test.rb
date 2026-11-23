# frozen_string_literal: true

require "test_helper"

class TodayFinalePartialTest < ActiveSupport::TestCase
  setup do
    @erb = Rails.root.join("app/views/dashboard/_today_finale.html.erb").read
  end

  test "finale partial orders Continue before Share with primary and plural labels" do
    assert_includes @erb, 't("dash.finale.continue")'
    assert_includes @erb, 't("dash.finale.share")'
    assert_includes @erb, "dash.finale.battles_today_label.one"
    assert_includes @erb, "dash.finale.battles_today_label.other"
    refute_includes I18n.t("dash.finale.goal_line", goal: "X"), "🏔"
    refute_match(/dash\.finale\.battles_today(?!_label)/, @erb)

    continue_at = @erb.index("lp-today-finale__continue")
    share_at = @erb.index("lp-today-finale__share")
    assert continue_at
    assert share_at
    assert_operator continue_at, :<, share_at
    assert_match(/lp-cta.*lp-today-finale__continue/, @erb)
    assert_match(/lp-btn-3d is-white.*lp-today-finale__share/, @erb)
  end
end
