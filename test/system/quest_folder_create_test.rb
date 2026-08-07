# frozen_string_literal: true

require "application_system_test_case"

class QuestFolderCreateTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      next_win: "Interview",
      today_mission: "Apply",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Find a job", position: 0
    )
    @camp = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Learn German", position: 0
    )
  end

  test "New Quest create shows the quest inline under climb path" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_selector ".lp-climb-path__new-quest-btn", text: /New Quest/i, wait: 5

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/quest-folder-create-before.png")

    find(".lp-climb-path__new-quest-btn", text: /New Quest/i).click
    assert_selector "body > .lp-rpg-float-create:not([hidden])", wait: 3
    assert_selector ".lp-rpg-float-create__heading", text: /New Quest/i

    card = find("body > .lp-rpg-float-create .lp-rpg-float-create__card")
    card.fill_in "title", with: "Vocabulary"
    card.find(".lp-rpg-float-create__btn.is-create").click

    page.save_screenshot("/opt/cursor/artifacts/screenshots/quest-folder-create-after.png")

    assert @user.strategy_goals.for_kind("project").exists?(title: "Vocabulary", parent_id: @camp.id),
           "Quest should be saved"
    created = @camp.children.find_by!(title: "Vocabulary")
    assert_selector ".lp-climb-path__quests[open] .lp-climb-path__quest-title", text: /Vocabulary/i, wait: 5
    assert_selector ".lp-climb-path__quest-add-input", visible: :all
    assert_no_selector ".lp-qs-detail"
    assert_current_path life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: created.id), wait: 5
  end
end
