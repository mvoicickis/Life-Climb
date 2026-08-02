# frozen_string_literal: true

require "application_system_test_case"

# Regression: Turbo form posts used to hit a no-op stream (record saved, sheet unchanged).
class QuestFolderTurboCreateTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Find a job",
      ideal_scene: "Hired", current_reality: "Searching", next_win: "Interview",
      today_mission: "Apply", closer_percent: 20, route_mission: true
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

  test "Turbo create shows the new Quest in the sheet" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    find(".lp-qs-new__btn", text: /New Quest/i).click
    assert_selector "body > .lp-rpg-float-create:not([hidden])", wait: 3

    card = find("body > .lp-rpg-float-create .lp-rpg-float-create__card")
    card.fill_in "title", with: "Vocabulary"
    # Force Turbo Drive to own the submit (the bug path when data-turbo=false is absent).
    page.execute_script(<<~JS)
      document.querySelector("body > .lp-rpg-float-create form")?.removeAttribute("data-turbo");
    JS
    card.find(".lp-rpg-float-create__btn.is-create").click

    assert_selector ".lp-qs-detail.is-open .lp-qs-detail__title", text: /Vocabulary/i, wait: 5
    assert @user.strategy_goals.for_kind("project").exists?(title: "Vocabulary", parent_id: @camp.id),
           "Quest should be saved"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/quest-folder-turbo-create-fixed.png")
  end
end
