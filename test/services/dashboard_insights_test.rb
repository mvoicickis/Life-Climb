require "test_helper"

class DashboardInsightsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @habit = habits(:one)
    @habit.update!(show_on_home: true, active: true, stat_type: "growth")
  end

  test "streak counts consecutive logged days ending today" do
    @user.daily_logs.delete_all
    @habit.daily_logs.create!(logged_on: Date.current - 2, amount: 1)
    @habit.daily_logs.create!(logged_on: Date.current - 1, amount: 2)
    @habit.daily_logs.create!(logged_on: Date.current, amount: 3)

    insights = DashboardInsights.new(@user.reload, trackers: [ @habit ])
    assert_equal 3, insights.streak_days
  end

  test "week series returns seven points" do
    insights = DashboardInsights.new(@user, trackers: [ @habit ])
    series = insights.week_series
    assert_equal 7, series.size
    assert series.first.key?(:percent)
  end

  test "focus tips mention off track habits" do
    @user.daily_logs.delete_all
    @habit.daily_logs.create!(logged_on: Date.yesterday, amount: 10)
    @habit.daily_logs.create!(logged_on: Date.current, amount: 2)

    insights = DashboardInsights.new(@user.reload, trackers: [ @habit ])
    assert insights.focus_tips.any? { |tip| tip.include?(@habit.name) }
  end
end

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "today board shows summary streak and focus sections" do
    user = users(:one)
    sign_in_as user

    get dashboard_path
    assert_response :success
    assert_match(/Day streak/, response.body)
    assert_match(/Weekly progress/, response.body)
    assert_match(/Focus for tomorrow/, response.body)
    assert_match(/Am I becoming a better version of myself/, response.body)
  end
end
