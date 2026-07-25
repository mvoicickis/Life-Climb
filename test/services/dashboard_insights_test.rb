require "test_helper"

class DashboardInsightsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @habit = habits(:one)
    @habit.update!(show_on_home: true, active: true, stat_type: "growth", name: "Walking", unit: "steps")
  end

  test "streak counts consecutive logged days ending today" do
    @user.daily_logs.delete_all
    @habit.daily_logs.create!(logged_on: Date.current - 2, amount: 1)
    @habit.daily_logs.create!(logged_on: Date.current - 1, amount: 2)
    @habit.daily_logs.create!(logged_on: Date.current, amount: 3)

    insights = DashboardInsights.new(@user.reload, trackers: [ @habit ])
    assert_equal 3, insights.streak_days
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
    assert_match(/Walk|Noej/i, tip)
  end
end

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "today board shows premium sections without card share buttons" do
    user = users(:one)
    sign_in_as user

    get dashboard_path
    assert_response :success
    assert_match(/Day streak|Dienu sērija/, response.body)
    assert_match(/Weekly progress|Nedēļas progress/, response.body)
    assert_match(/Focus for tomorrow|Fokuss rītdienai/, response.body)
    assert_match(/Track what matters most|Seko tam, kas tev/, response.body)
    assert_match(/week-chart/, response.body)
    refute_match(/>\s*Share\s*</, response.body)
  end
end

class LocalesControllerTest < ActionDispatch::IntegrationTest
  test "can switch locale to latvian" do
    sign_in_as users(:one)
    patch locale_path(locale: :lv)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match(/Šodien|Today/, response.body)
    refute_match(/>\s*(Home|Sākums|Dashboard|Panelis)\s*</, response.body)
  end
end
