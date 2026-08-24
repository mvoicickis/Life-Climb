# frozen_string_literal: true

require "application_system_test_case"

class CampSheetNavTest < ApplicationSystemTestCase
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
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "MVP path", position: 0
    )
    @camp_a = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Get first 100 users", position: 0
    )
    @camp_b = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Ship landing page", position: 1
    )
    @camp_a_leaf = practice_leaf_for!(@camp_a)
    host_a = Strategy::EnsureFolderQuest.call(folder: @camp_a_leaf)
    host_a.practice_tasks.create!(
      user: @user, title: "Ask 5 friends for feedback", position: 0
    )
    @camp_b_leaf = practice_leaf_for!(@camp_b)
    host_b = Strategy::EnsureFolderQuest.call(folder: @camp_b_leaf)
    host_b.practice_tasks.create!(
      user: @user, title: "Draft hero headline", position: 0
    )
  end

  test "⋮ Objectives opens each project's quest sheet" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp_a_leaf.id)
    open_mountain_list_fallback!
    assert_selector "#climb-path-project-#{@camp_a.id}", text: /Get first 100 users/i, wait: 5
    assert_selector "#climb-path-project-#{@camp_b.id}", text: /Ship landing page/i
    assert_no_selector "a.lp-climb-path__link"
    assert_no_selector ".lp-climb-path__node.is-locked"

    open_project_objectives(@camp_a)
    within("dialog#section-objectives-#{@camp_a.id}") do
      assert_selector ".lp-climb-path__quest-title", text: /Get first 100 users/i
      assert_selector ".lp-qs-obj__text[value='Ask 5 friends for feedback']", visible: :all
      assert_no_selector ".lp-qs-obj__text[value='Draft hero headline']"
    end
    find("dialog#section-objectives-#{@camp_a.id} .lp-strategy-sheet__close").click

    open_project_objectives(@camp_b)
    within("dialog#section-objectives-#{@camp_b.id}") do
      assert_selector ".lp-climb-path__quest-title", text: /Ship landing page/i, wait: 5
      assert_selector ".lp-qs-obj__text[value='Draft hero headline']", visible: :all, wait: 3
      assert_no_selector ".lp-qs-obj__text[value='Ask 5 friends for feedback']"
    end

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/camp-sheet-nav.png")
  end

  test "empty camp has no New Quest on the card" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    @camp_a.complete!
    @camp_b.complete!
    empty = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Empty camp", position: 2
    )

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: empty.id)
    open_mountain_list_fallback!
    assert_selector "#trail-camp-#{empty.id}", text: /Empty camp/i, wait: 5
    assert_selector "#climb-path-project-#{empty.id}", text: /Empty camp/i, visible: :all, wait: 5
    assert_no_selector ".lp-rpg-section-head"
    assert_no_selector ".lp-rpg-practice-cats__hint"
    assert_no_selector ".lp-qs-board__title"
    assert_no_selector ".lp-climb-path__new-quest-btn"
    assert_no_selector ".lp-rpg-practice-focus.is-entered", visible: true
    assert_no_selector "#climb-path-project-#{empty.id} .lp-climb-path__quest-add"
    assert_selector "#climb-path-project-#{empty.id} [data-action='click->plan-card-menu#objectives']", visible: :all
  end
end
