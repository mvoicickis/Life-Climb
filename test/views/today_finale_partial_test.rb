# frozen_string_literal: true

require "test_helper"

class TodayFinalePartialTest < ActionView::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    @finale = Today::FinaleMoment::Result.new(
      battles_today: 1,
      goal_title: "Learn piano",
      camp_current: 1,
      camp_total: 3,
      camp_fill: 0.33,
      share_text: "share"
    )
  end

  def current_user
    @user
  end

  test "finale renders Continue primary before Share and pluralizes battle label" do
    html = render(partial: "dashboard/today_finale", locals: { finale: @finale })

    assert_includes html, I18n.t("dash.finale.continue")
    assert_includes html, I18n.t("dash.finale.share")
    assert_includes html, I18n.t("dash.finale.battles_today_label.one")
    refute_includes html, "🏔"
    refute_includes html, "Battles today"
    continue_at = html.index("lp-today-finale__continue")
    share_at = html.index("lp-today-finale__share")
    assert continue_at, "expected Continue control in finale partial"
    assert share_at, "expected Share control in finale partial"
    assert_operator continue_at, :<, share_at
    assert_match(/lp-cta.*lp-today-finale__continue/m, html)
  end
end
