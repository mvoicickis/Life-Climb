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

  test "switch between camps and delete an unnecessary checkpoint" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @junk.id)
    assert_selector ".lp-rpg-section-card.is-selected", text: /wewe/i, wait: 5
    assert_selector ".lp-rpg-sections__item.is-selected .lp-rpg-section-card__menu-btn"

    find("a.lp-rpg-section-card", text: /Daily battles/i, wait: 3).click
    assert_selector ".lp-rpg-section-card.is-selected", text: /Daily battles/i, wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @junk.id)
    assert_selector ".lp-rpg-section-card.is-selected", text: /wewe/i, wait: 5
    find(".lp-rpg-sections__item.is-selected .lp-rpg-section-card__menu-btn").click
    find(".lp-rpg-section-card__menu-item.is-danger", text: /Delete/i).click
    assert_selector "dialog[open] .lp-strategy-sheet__title", text: /Delete Checkpoint/i, wait: 3
    within("dialog[open]") { click_button "Delete" }

    assert_no_selector ".lp-rpg-section-card", text: /wewe/i, wait: 5
    assert_not @user.strategy_goals.exists?(id: @junk.id)
    assert_selector ".lp-rpg-section-card.is-selected, .lp-rpg-section-card.is-current", text: /Daily battles/i

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/checkpoint-camp-manage.png")
  end
end
