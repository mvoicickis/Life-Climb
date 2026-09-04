# frozen_string_literal: true

require "application_system_test_case"

class PushOfferAfterWinTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.update!(
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_permission_denied_at: nil
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
      title: "Stream Battle", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    dismiss_onboarding_missions!(@user)
    @user.habits.create!(
      name: "Meditate", unit: "times", points: 5, frequency: "daily",
      active: true, show_on_home: true, stat_type: "growth"
    )
    @todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
  end

  def browser_console_errors
    page.driver.browser.logs.get(:browser).select { |entry| entry.level == "SEVERE" }
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

  test "push offer card appears after first battle win" do
    sign_in_and_visit_today!

    assert_selector "#today-push-offer-host[data-controller='push-offer']", visible: :all
    assert_selector "form.lp-today-v2-row__check-form[data-turbo-stream='true']", visible: :all

    find(".lp-today-v2-row[data-todo-id='#{@todo.id}'] .lp-today-v2-row__check").click

    assert_no_selector ".lp-today-v2-row[data-todo-id='#{@todo.id}']", wait: 10
    assert_selector ".lp-push-offer", wait: 5
    assert_selector ".lp-push-offer__headline", text: /reminder tomorrow morning/i

    errors = browser_console_errors
    assert errors.none? { |entry| entry.message.include?("hasTarget is not a function") },
           "console errors: #{errors.map(&:message).join("\n")}"
  end
end
