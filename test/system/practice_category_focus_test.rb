# frozen_string_literal: true

require "application_system_test_case"

class PracticeCategoryFocusSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Learn German",
      ideal_scene: "Fluent",
      current_reality: "Beginner",
      next_win: "A1",
      today_mission: "Learn 15 words",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Learn German", position: 0
    )
    @lang = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Language skills", position: 0
    )
    @vocab = @lang.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Vocabulary", position: 0
    )
    @grammar = @lang.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Grammar", position: 1
    )
    @practice = @vocab.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Learn 15 new words",
      scheduled_on: Date.current, position: 0
    )
    @flashcards = @vocab.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Flashcards",
      scheduled_on: Date.current + 1.day, position: 1
    )
  end

  test "path lists camps; expand folder for practices; toggle today's practice" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @lang.id)
    assert_selector "#strategy-world.lp-rpg", wait: 5
    assert_selector ".lp-rpg-practice-cats", visible: true
    assert_selector ".lp-rpg-practice-cat__title", text: /Vocabulary/i
    assert_selector ".lp-rpg-practice-cat__title", text: /Grammar/i
    assert_no_selector ".lp-rpg-camp-folder[open][data-category-id='#{@vocab.id}']"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/practice-cats-level-a.png")

    find(".lp-rpg-practice-cat", text: /Vocabulary/i).click
    assert_selector ".lp-rpg-camp-folder[open][data-category-id='#{@vocab.id}']", wait: 3
    assert_no_selector ".lp-rpg-camp-switch"
    assert_selector ".lp-rpg-camp-folder[open] .lp-rpg-quest-row__check", minimum: 1, visible: :all, wait: 3
    assert_selector ".lp-rpg-camp-folder[open] .lp-rpg-quest-row__title", text: /Learn 15/i, visible: :all
    assert_selector ".lp-rpg-camp-folder[open] .lp-rpg-quest-row__title", text: /Flashcards/i, visible: :all
    assert_selector ".lp-rpg-practice-add", text: /Prepare New Practice/i, visible: :all
    assert_no_selector ".lp-rpg-breadcrumbs"
    assert_no_selector ".lp-rpg-section-head"
    assert_selector ".lp-rpg-section-card", text: /Language skills/i, visible: :all
    assert_selector ".lp-rpg-practice-cat__title", text: /Grammar/i

    page.save_screenshot("/opt/cursor/artifacts/screenshots/practice-cats-level-b.png")

    find(".lp-rpg-practice-cat", text: /Vocabulary/i).click
    assert_no_selector ".lp-rpg-camp-folder[open][data-category-id='#{@vocab.id}']", wait: 3
    assert_selector ".lp-rpg-practice-cat__title", text: /Grammar/i

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @vocab.id)
    assert_selector ".lp-rpg-camp-folder[open][data-category-id='#{@vocab.id}']", wait: 5
    assert_selector ".lp-rpg-quest-row.is-ready .lp-rpg-quest-row__check[checked]", visible: :all
    assert_selector ".lp-rpg-quest-row__check[aria-label='Flashcards']:not(:checked)", visible: :all

    page.execute_script(<<~JS)
      const el = document.querySelector(".lp-rpg-camp-folder[open] .lp-rpg-quest-row__check[aria-label='Flashcards']");
      el?.scrollIntoView({ block: "center" });
      el?.form?.requestSubmit();
    JS
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      break if @flashcards.reload.scheduled_on == Date.current
      raise "Flashcards was not planned for today" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.1
    end

    page.execute_script(<<~JS)
      const el = document.querySelector(".lp-rpg-camp-folder[open] .lp-rpg-quest-row__check[aria-label='Learn 15 new words']");
      el?.scrollIntoView({ block: "center" });
      el?.form?.requestSubmit();
    JS
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      break if @practice.reload.scheduled_on == Date.current + 1.day
      raise "Learn 15 words stayed planned for today" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.1
    end
  end

  test "Prepare New Practice Cancel closes the portaled floating card" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @vocab.id)
    assert_selector ".lp-rpg-camp-folder[open][data-category-id='#{@vocab.id}']", wait: 5

    page.execute_script(<<~JS)
      const trigger = document.querySelector(".lp-rpg-camp-folder[open] .lp-rpg-practice-add");
      trigger?.scrollIntoView({ block: "center" });
      trigger?.click();
    JS
    assert_selector "body > .lp-rpg-float-create:not([hidden])", wait: 3
    assert_selector ".lp-rpg-float-create__heading", text: /Prepare New Practice/i

    find("body > .lp-rpg-float-create .lp-rpg-float-create__btn.is-cancel", text: /Cancel/i).click
    assert_no_selector "body > .lp-rpg-float-create:not([hidden])", wait: 3
  end
end
