# frozen_string_literal: true

require "application_system_test_case"

class PushOfferIosInstallTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.update!(
      character: "fox",
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_permission_denied_at: nil,
      push_offer_last_shown_on: nil
    )
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Goal", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    battle = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "iOS Battle", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    dismiss_onboarding_missions!(@user)
    @user.push_subscriptions.delete_all
    @todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
  end

  def teardown
    reset_emulated_user_agent!
  end

  def reset_emulated_user_agent!
    page.driver.browser.execute_cdp("Emulation.setUserAgentOverride", userAgent: "")
  rescue StandardError
    nil
  end

  def emulate_iphone_safari_ua!
    page.driver.browser.execute_cdp(
      "Emulation.setUserAgentOverride",
      userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    )
  end

  test "ios safari not installed shows home screen steps without a button" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!
    emulate_iphone_safari_ua!
    visit dashboard_path
    assert_selector "#today-dash-root", wait: 8

    find(".lp-today-v2-row[data-todo-id='#{@todo.id}'] .lp-today-v2-row__check").click

    assert_no_selector ".lp-today-v2-row[data-todo-id='#{@todo.id}']", wait: 10
    assert_selector ".lp-push-offer", wait: 8
    assert_selector ".lp-push-offer__headline", text: I18n.t("dash.push_offer.ios_headline")
    assert_selector ".lp-push-offer__body", text: I18n.t("dash.push_offer.ios_steps")
    assert_no_selector ".lp-push-offer__yes"
    assert_no_selector ".lp-push-offer--row"
  end
end
