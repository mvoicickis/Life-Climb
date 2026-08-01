# frozen_string_literal: true

require "application_system_test_case"

class FloatingCheckpointCreateTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 700)

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
    camps = [
      "Authentication",
      "Daily battles",
      "Dashboard"
    ].each_with_index.map do |title, i|
      @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: title, position: i
      )
    end
    camps[0].complete!
    camps[1].children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Design battle card",
      scheduled_on: Date.current, position: 0
    )
    @current = camps[1]
  end

  test "plus opens floating planning card with focus and Esc closes" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5
    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id, focus_id: @current.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5
    assert_no_selector ".lp-first-climb-shell"

    find(".lp-rpg-node.is-slot-focus .lp-rpg-node__add-trigger", wait: 5).click

    assert_selector "body > .lp-rpg-float-create:not([hidden])", wait: 3
    assert_selector ".lp-rpg-float-create__heading", text: /New Checkpoint/i
    assert_selector ".lp-rpg-float-create__input[placeholder='Checkpoint name']"
    assert_equal "title", page.evaluate_script("document.activeElement && document.activeElement.name")

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/mountain-checkpoint-float-create.png")

    page.driver.browser.action.send_keys(:escape).perform
    assert_no_selector "body > .lp-rpg-float-create:not([hidden])", wait: 3
    assert_selector ".lp-rpg-node.is-slot-focus .lp-rpg-node__add:not([open])"
  end

  test "cancel button closes the portaled floating create card" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id, focus_id: @current.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5

    find(".lp-rpg-node.is-slot-focus .lp-rpg-node__add-trigger", wait: 5).click
    assert_selector "body > .lp-rpg-float-create:not([hidden])", wait: 3

    find("body > .lp-rpg-float-create .lp-rpg-float-create__btn.is-cancel", text: /Cancel/i).click
    assert_no_selector "body > .lp-rpg-float-create:not([hidden])", wait: 3
    assert_selector ".lp-rpg-node.is-slot-focus .lp-rpg-node__add:not([open])"
  end

  test "create checkpoint saves and keeps the new camp visible on the trail" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id, focus_id: @current.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5

    find(".lp-rpg-node.is-slot-focus .lp-rpg-node__add-trigger", wait: 5).click
    assert_selector "body > .lp-rpg-float-create:not([hidden])", wait: 3

    within("body > .lp-rpg-float-create") do
      fill_in "title", with: "Notifications camp"
      click_button "Create Checkpoint"
    end

    assert_selector ".lp-rpg-node.is-planning-focus", text: /Notifications camp/i, wait: 5
    assert_selector ".lp-rpg-node.is-slot-focus", text: /Notifications camp/i
    assert_selector ".lp-rpg-practice-focus.is-entered .lp-rpg-practice-focus__title", text: /Notifications camp/i, visible: :all
    assert @user.strategy_goals.for_kind("project").exists?(title: "Notifications camp", parent_id: @plan.id)

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/checkpoint-create-visible.png")
  end
end
