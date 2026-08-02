# frozen_string_literal: true

require "application_system_test_case"

class QuestFoldersMockupTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(430, 900)

    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship the MVP",
      ideal_scene: "Live", current_reality: "Building", next_win: "Launch",
      today_mission: "Design", closer_percent: 40, route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "MVP path", position: 0
    )
    @camp = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Mountain page", position: 0
    )
    # Legacy: days hang directly under the path-level camp (the user's screenshot state).
    @quest = @user.strategy_goals.new(
      user: @user, life_area: @area, life_journey: @journey, parent: @camp,
      horizon: "day", title: "Making Mountain Page", scheduled_on: Date.current,
      repeat: "daily", position: 0
    )
    @quest.save!(validate: false)
    @quest.practice_tasks.create!(user: @user, title: "Design mountain layout", position: 0, completed_at: Time.current)
    @quest.practice_tasks.create!(user: @user, title: "Build mountain header section", position: 1, completed_at: Time.current)
    @quest.practice_tasks.create!(user: @user, title: "Add progress tracking UI", position: 2, completed_at: Time.current)
    @quest.practice_tasks.create!(user: @user, title: "Make page responsive", position: 3)
    @quest.practice_tasks.create!(user: @user, title: "Polish visuals and animations", position: 4)

    @other = @user.strategy_goals.new(
      user: @user, life_area: @area, life_journey: @journey, parent: @camp,
      horizon: "day", title: "Camp Screen Design", scheduled_on: Date.current + 1,
      repeat: "daily", position: 1
    )
    @other.save!(validate: false)
    2.times { |i| @other.practice_tasks.create!(user: @user, title: "Task #{i + 1}", position: i, completed_at: (i.zero? ? Time.current : nil)) }
  end

  test "legacy Quest Folders board matches folder card mockup" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5
    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world", wait: 5

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camp.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5
    assert_selector ".lp-rpg-camps__kicker", text: /Quest Folders/i, wait: 5
    assert_no_selector ".lp-rpg-camps__new", text: /New Quest Folder/i
    assert_selector ".lp-rpg-camp-folder.is-legacy-scope.is-quest-board", wait: 3
    assert_selector ".lp-rpg-practice-folder__title", text: /Making Mountain Page/i
    assert_selector ".lp-rpg-practice-folder__badge", text: /Every day/i
    assert_selector ".lp-rpg-practice-folder__objectives-label", text: /Objectives/i
    assert_selector ".lp-rpg-practice-folder__objectives-count", text: /3 \/ 5 completed/i
    assert_selector ".lp-rpg-practice-task__title", text: /Design mountain layout/i
    assert_selector ".lp-rpg-practice-folder__add-reveal", text: /Add Objective/i
    assert_selector ".lp-rpg-practice-folder__plan-title", text: /Plan for Today/i
    assert_selector ".lp-rpg-practice-folder__title", text: /Camp Screen Design/i

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/quest-folders-mockup-match.png")
  end
end
