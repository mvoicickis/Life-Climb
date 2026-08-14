# frozen_string_literal: true

require "application_system_test_case"

class CheckpointCampManageTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship the MVP",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Design battle card",
      closer_percent: 40,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "MVP path", position: 0
    )
    @first = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Daily battles", position: 0
    )
    @junk = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "wewe", position: 1
    )
    @first_leaf = practice_leaf_for!(@first)
    @first_leaf.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Design battle card",
      scheduled_on: Date.current, position: 0
    )
  end

  test "current section menu can delete the active checkpoint" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @first.id)
    assert_selector "#climb-path-project-#{@first.id}", text: /Daily battles/i, wait: 5
    assert_selector "#climb-path-project-#{@first.id} .lp-climb-path__menu-btn"
    assert_selector "#climb-path-project-#{@junk.id}", text: /wewe/i
    assert_selector "#climb-path-project-#{@junk.id} .lp-climb-path__menu-btn"

    before_path = page.current_path
    page.execute_script(<<~JS)
      document.querySelector('#climb-path-project-#{@junk.id}')?.scrollIntoView({ block: 'center' });
    JS
    find("#climb-path-project-#{@junk.id} .lp-climb-path__menu-btn").click
    assert_selector ".lp-climb-path__menu:not([hidden])", wait: 3
    assert_equal before_path, page.current_path
    assert_selector "#climb-path-project-#{@junk.id}", text: /wewe/i

    page.execute_script(<<~JS)
      document.querySelector('.lp-climb-path__menu:not([hidden]) .lp-climb-path__menu-item.is-danger')?.click();
    JS
    assert_selector "dialog[open] .lp-strategy-sheet__title", text: /Delete Checkpoint/i, wait: 3
    within("dialog[open]") { click_button "Delete" }

    assert_no_selector ".lp-climb-path__node", text: /wewe/i, wait: 5
    assert_not @user.strategy_goals.exists?(id: @junk.id)
    assert_selector "#climb-path-project-#{@first.id}", text: /Daily battles/i

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/checkpoint-camp-manage.png")
  end
end
