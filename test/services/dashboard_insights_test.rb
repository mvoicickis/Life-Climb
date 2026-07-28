require "test_helper"

class DashboardInsightsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @habit = habits(:one)
    @habit.update!(show_on_home: true, active: true, stat_type: "growth", name: "Walking", unit: "steps")
  end

  test "celebrations ignore streaks and reward real progress" do
    @user.daily_logs.delete_all
    @habit.daily_logs.create!(logged_on: Date.current - 2, amount: 1)
    @habit.daily_logs.create!(logged_on: Date.current - 1, amount: 2)
    @habit.daily_logs.create!(logged_on: Date.current, amount: 3)

    insights = DashboardInsights.new(@user.reload, trackers: [ @habit ])
    kinds = insights.celebrations.map { |item| item[:kind] }
    refute_includes kinds, :streak
  end

  test "week series returns seven rolling days" do
    insights = DashboardInsights.new(@user, trackers: [ @habit ])
    series = insights.week_series
    assert_equal 7, series.size
    assert_equal Date.current, series.last[:date]
    assert series.first.key?(:percent)
  end

  test "focus tips use encouraging language" do
    @user.daily_logs.delete_all
    @habit.daily_logs.create!(logged_on: Date.yesterday, amount: 1000)
    @habit.daily_logs.create!(logged_on: Date.current, amount: 625)

    insights = DashboardInsights.new(@user.reload, trackers: [ @habit ])
    tip = insights.focus_tips.first
    assert_match(/375/, tip)
    assert_match(/Walk|Noej|Geh|Camina/i, tip)
  end

  test "prioritized trackers put needs-work first" do
    better = @habit
    better.update!(name: "Walking", unit: "steps", position: 1)
    worse = @user.habits.create!(
      name: "Reading",
      unit: "pages",
      points: 5,
      frequency: "daily",
      stat_type: "growth",
      show_on_home: true,
      active: true,
      position: 2
    )
    same = @user.habits.create!(
      name: "Water",
      unit: "glasses",
      points: 5,
      frequency: "daily",
      stat_type: "growth",
      show_on_home: true,
      active: true,
      position: 3
    )

    @user.daily_logs.delete_all
    better.daily_logs.create!(logged_on: Date.yesterday, amount: 100)
    better.daily_logs.create!(logged_on: Date.current, amount: 150)
    worse.daily_logs.create!(logged_on: Date.yesterday, amount: 10)
    worse.daily_logs.create!(logged_on: Date.current, amount: 4)
    same.daily_logs.create!(logged_on: Date.yesterday, amount: 5)
    same.daily_logs.create!(logged_on: Date.current, amount: 5)

    ranked = DashboardInsights.new(@user.reload, trackers: [ better, worse, same ]).prioritized_trackers
    assert_equal [ worse, same, better ].map(&:id), ranked.map(&:id)
  end
end

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "today board shows battle home after climb is seeded" do
    user = users(:one)
    seed_climb!(user, today_mission: "Finish authentication")
    sign_in_as user

    get dashboard_path
    assert_response :success
    assert_match(/Today|Battle|Action Points/i, response.body)
    assert_match(/Finish authentication/, response.body)
    assert_select ".lp-dash-nav"
    refute_match(/Morale/, response.body)
  end
end

class LocalesControllerTest < ActionDispatch::IntegrationTest
  teardown { I18n.locale = I18n.default_locale }

  test "can switch locale to latvian" do
    user = users(:one)
    seed_climb!(user)
    sign_in_as user
    patch locale_path(locale: :lv)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    get settings_path
    assert_match(/Iestatījumi/, response.body)
  end

  test "can switch locale to german" do
    user = users(:one)
    seed_climb!(user)
    sign_in_as user
    patch locale_path(locale: :de)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_match(/Heute|Berg|Du/, response.body)
    get settings_path
    assert_match(/Einstellungen/, response.body)
  end

  test "can switch locale to spanish" do
    user = users(:one)
    seed_climb!(user)
    sign_in_as user
    patch locale_path(locale: :es)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    get settings_path
    assert_match(/Ajustes/, response.body)
  end
end
