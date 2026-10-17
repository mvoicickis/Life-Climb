# frozen_string_literal: true

require "test_helper"

class PushOfferTodayTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Code",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Plan", position: 0
    )
    @project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Project", position: 0
    )
    @project_leaf = practice_leaf_for!(@project)
    @battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @project_leaf, horizon: "day",
      title: "Win this fight", scheduled_on: Date.current, position: 0
    )
    @user.update!(
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_permission_denied_at: nil,
      push_offer_last_shown_on: nil,
      push_offer_show_days: 0
    )
    @user.push_subscriptions.delete_all
    clear_battle_wins!(@user)
  end

  def push_offer_host_attrs
    assert_select "#today-push-offer-host[data-controller='push-offer']", count: 1
    assert_select "#today-push-offer-host"
  end

  def clear_battle_wins!(user)
    user.strategy_goals.battles.update_all(completed_at: nil)
    user.daily_todos.where.not(completed_at: nil).update_all(completed_at: nil)
  end

  test "eligible user who never won does not show offer on connect" do
    get dashboard_path
    assert_response :success
    push_offer_host_attrs
    host = css_select("#today-push-offer-host").first
    assert_equal "false", host["data-push-offer-show-on-connect-value"]
    assert_equal "true", host["data-push-offer-compact-value"]
    assert_equal "false", host["data-push-offer-show-not-now-value"]
    assert_equal "", host["data-push-offer-goal-title-value"].to_s
  end

  test "all clear battlefield keeps green add battle pill in markup" do
    @battle.update!(completed_at: Time.current)
    get dashboard_path
    assert_response :success
    assert_select "a.lp-today-empty-cta__pill", minimum: 1
  end

  test "prior battle win without win today enables show on connect" do
    zone = Battles::WinsOnLocalDate.time_zone_for(@user)
    travel_to Time.find_zone!(zone).local(2026, 8, 6, 12, 0, 0) do
      @user.update!(created_at: Time.find_zone!(zone).local(2020, 1, 1, 0, 0, 0))
      @battle.update!(completed_at: Time.find_zone!(zone).local(2026, 8, 5, 9, 0, 0))

      get dashboard_path
      assert_response :success
      host = css_select("#today-push-offer-host").first
      assert_equal "true", host["data-push-offer-show-on-connect-value"]
      assert_equal "true", host["data-push-offer-mark-shown-on-display-value"]
    end
  end

  test "camp sheet win today enables show on connect on next today visit" do
    post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream
    assert_response :ok
    assert_match "data-battle-day-stream-bridge-push-offer-eligible-value=\"false\"", response.body

    get dashboard_path
    assert_response :success
    host = css_select("#today-push-offer-host").first
    assert_equal "true", host["data-push-offer-show-on-connect-value"]
  end

  test "dismissed offer does not show on connect again same day" do
    post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream
    assert_response :ok

    delete push_offer_path
    assert_response :no_content

    get dashboard_path
    assert_response :success
    host = css_select("#today-push-offer-host").first
    assert_equal "false", host["data-push-offer-show-on-connect-value"]
  end

  test "mountain page has no push offer host" do
    @battle.update!(completed_at: Time.current)
    get life_journey_path(@journey)
    assert_response :success
    assert_select "#mountain-push-offer-host", count: 0
    assert_select "#today-push-offer-host", count: 0
  end
end
