# frozen_string_literal: true

require "application_system_test_case"

class PushOfferAndroidInstallTest < ApplicationSystemTestCase
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
      title: "Android Battle", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    dismiss_onboarding_missions!(@user)
    @user.push_subscriptions.delete_all
    @todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
  end

  def teardown
    reset_emulated_user_agent!
    clear_captured_install_prompt!
  end

  def reset_emulated_user_agent!
    page.driver.browser.execute_cdp("Emulation.setUserAgentOverride", userAgent: "")
  rescue StandardError
    nil
  end

  def clear_captured_install_prompt!
    page.execute_script("window.__lpClearInstallPrompt?.()")
  rescue StandardError
    nil
  end

  def sign_in_and_visit_today!
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!
    visit dashboard_path
    assert_selector "#today-dash-root", wait: 8
  end

  def emulate_android_ua!
    page.driver.browser.execute_cdp(
      "Emulation.setUserAgentOverride",
      userAgent: "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
    )
  end

  def block_install_prompt!
    page.execute_script(<<~JS)
      window.addEventListener("beforeinstallprompt", (event) => {
        event.preventDefault();
        event.stopImmediatePropagation();
      }, { capture: true });
    JS
  end

  def capture_install_prompt!
    page.execute_script(<<~JS)
      const evt = new Event("beforeinstallprompt", { cancelable: true });
      evt.prompt = () => Promise.resolve();
      evt.userChoice = Promise.resolve({ outcome: "accepted", platform: "web" });
      window.dispatchEvent(evt);
    JS
  end

  test "android with install prompt shows add to home screen after win" do
    visit new_session_path
    block_install_prompt!
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!
    emulate_android_ua!
    visit dashboard_path
    capture_install_prompt!

    find(".lp-today-v2-row[data-todo-id='#{@todo.id}'] .lp-today-v2-row__check").click

    assert_no_selector ".lp-today-v2-row[data-todo-id='#{@todo.id}']", wait: 10
    assert_selector ".lp-push-offer", wait: 8
    assert_selector ".lp-push-offer__headline", text: /home screen/i
    assert_selector ".lp-push-offer__yes", text: /Add to home screen/i
  end

  test "android without install prompt falls back to remind me" do
    visit new_session_path
    block_install_prompt!
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!
    emulate_android_ua!
    visit dashboard_path

    find(".lp-today-v2-row[data-todo-id='#{@todo.id}'] .lp-today-v2-row__check").click

    assert_no_selector ".lp-today-v2-row[data-todo-id='#{@todo.id}']", wait: 10
    assert_selector ".lp-push-offer", wait: 8
    assert_selector ".lp-push-offer__headline", text: /reminder tomorrow morning/i
    assert_selector ".lp-push-offer__yes", text: /Remind me/i
  end
end
