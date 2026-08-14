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
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
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
    @vocab = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Vocabulary", position: 1
    )
    @grammar = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Grammar", position: 2
    )
    @host = Strategy::EnsureFolderQuest.call(folder: @vocab)
    @host.practice_tasks.create!(user: @user, title: "Learn 15 new words", position: 0)
    @host.practice_tasks.create!(user: @user, title: "Flashcards", position: 1)
    Strategy::EnsureFolderQuest.call(folder: @grammar)
  end

  test "climb path lists every project; ⋮ Objectives opens the sheet" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @vocab.id)
    assert_selector "#strategy-world.lp-rpg", wait: 5
    assert_no_selector ".lp-qs-board__title"
    assert_selector "#climb-path-project-#{@vocab.id} .lp-climb-path__title", text: /Vocabulary/i
    assert_selector "#climb-path-project-#{@lang.id}", text: /Language skills/i, visible: :all
    assert_selector "#climb-path-project-#{@grammar.id}", text: /Grammar/i, visible: :all
    assert_no_selector ".lp-climb-path__new-quest-btn"
    assert_no_selector ".lp-climb-path__quests"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/practice-cats-level-a.png")

    open_project_objectives(@vocab)
    within("dialog#section-objectives-#{@vocab.id}") do
      assert_selector ".lp-climb-path__quest-title", text: /Vocabulary/i
      assert_selector ".lp-qs-obj__text[value='Learn 15 new words']", visible: :all
      assert_selector ".lp-qs-obj__text[value='Flashcards']", visible: :all
      assert_selector ".lp-climb-path__quest-add-input", visible: :all
      assert_selector ".lp-climb-path__quest-add-btn", text: /\AAdd\z/, visible: :all
      assert_no_selector "button.lp-qs-obj__check"
    end
    assert_no_selector ".lp-rpg-practice-add", text: /Prepare New Quest/i

    page.save_screenshot("/opt/cursor/artifacts/screenshots/practice-cats-level-b.png")

    find("dialog#section-objectives-#{@vocab.id} .lp-strategy-sheet__close").click

    open_project_objectives(@grammar)
    within("dialog#section-objectives-#{@grammar.id}") do
      assert_selector ".lp-climb-path__quest-title", text: /Grammar/i, wait: 5
    end
    find("dialog#section-objectives-#{@grammar.id} .lp-strategy-sheet__close").click

    open_project_objectives(@vocab)
    flash = @host.practice_tasks.find_by!(title: "Flashcards")
    page.execute_script(<<~JS)
      const el = document.querySelector("dialog[open] .lp-qs-obj__check");
      el?.scrollIntoView({ block: "center" });
      el?.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
    JS
    sleep 0.4
    assert_not flash.reload.completed?, "Quest checkbox must stay read-only"

    within("dialog#section-objectives-#{@vocab.id}") do
      find(".lp-climb-path__quest-add-input", visible: :all).set("Review verbs")
      find(".lp-climb-path__quest-add-btn", visible: :all).click
      assert_selector ".lp-qs-obj__text[value='Review verbs']", visible: :all, wait: 5
    end
    assert @host.practice_tasks.exists?(title: "Review verbs")

    page.save_screenshot("/opt/cursor/artifacts/screenshots/quest-space-add-btn-mobile.png")
  end

  test "empty path camp does not offer nested New Quest" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @lang.id)
    assert_no_selector ".lp-climb-path__new-quest-btn"
    assert_no_selector "#climb-path-project-#{@lang.id} .lp-climb-path__quest-add"
    assert_selector "#climb-path-project-#{@lang.id} [data-action='click->plan-card-menu#objectives']", visible: :all
  end
end
