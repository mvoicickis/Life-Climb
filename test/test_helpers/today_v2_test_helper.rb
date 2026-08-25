# frozen_string_literal: true

# Shared assertions for Today V2 battlefield UI (when @show_plan_route is false).
module TodayV2TestHelper
  def assert_today_v2_shell!
    assert_select ".lp-dash.is-today-v2", count: 1
    assert_select ".lp-today-v2-header", count: 1
    assert_select ".lp-today-v2-field", count: 1
    assert_select ".lp-dash-nav.is-today-v2", count: 1
  end

  def assert_no_legacy_today_shell!
    assert_select ".lp-dash-hero", count: 0
    assert_select ".lp-dash-timeline", count: 0
    assert_select ".lp-dash-daystrip", count: 0
    assert_select ".lp-dash-anytime", count: 0
    assert_select ".lp-dash-done-fold", count: 0
  end

  def assert_battle_row!(title:, camp: nil, todo: nil)
    assert_select ".lp-today-v2-row__title", text: title
    assert_select ".lp-today-v2-row__camp", text: /#{Regexp.escape(camp)}/ if camp
    assert_select ".lp-today-v2-row[data-todo-id=?]", todo.id.to_s if todo
  end

  def assert_battle_row_absent!(title:)
    assert_select ".lp-today-v2-row__title", text: title, count: 0
  end

  def dismiss_onboarding_missions!(user)
    user.missions.for_day(Date.current).primary.incomplete.find_each do |mission|
      Missions::Complete.call(user: user, mission: mission)
    end
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include TodayV2TestHelper
end
