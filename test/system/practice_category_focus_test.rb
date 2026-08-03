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
    @host = Strategy::EnsureFolderQuest.call(folder: @vocab)
    @host.practice_tasks.create!(user: @user, title: "Learn 15 new words", position: 0)
    @host.practice_tasks.create!(user: @user, title: "Flashcards", position: 1)
  end

  test "board lists quests; open detail; back returns to board; status-only checks" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @lang.id)
    assert_selector "#strategy-world.lp-rpg", wait: 5
    assert_selector ".lp-qs-board__title", text: /Your Quests/i
    assert_selector ".lp-qs-card__name", text: /Vocabulary/i
    assert_selector ".lp-qs-card__name", text: /Grammar/i
    assert_no_selector ".lp-qs-detail.is-open"

    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/practice-cats-level-a.png")

    find(".lp-qs-card", text: /Vocabulary/i).click
    assert_selector ".lp-qs-detail.is-open .lp-qs-detail__title", text: /Vocabulary/i, wait: 3
    assert_selector ".lp-qs-obj__text[value='Learn 15 new words']", visible: :all
    assert_selector ".lp-qs-obj__text[value='Flashcards']", visible: :all
    assert_selector ".lp-qs-detail__add-input", visible: :all
    assert_selector ".lp-qs-detail__add-btn", text: /\AAdd\z/, visible: :all
    assert_no_selector "button.lp-qs-obj__check"
    assert_no_selector ".lp-rpg-practice-add", text: /Prepare New Quest/i
    assert_selector ".lp-rpg-section-card", text: /Language skills/i, visible: :all

    page.save_screenshot("/opt/cursor/artifacts/screenshots/practice-cats-level-b.png")

    find(".lp-qs-detail__back").click
    assert_no_selector ".lp-qs-detail.is-open", wait: 3
    assert_selector ".lp-qs-card__name", text: /Grammar/i

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @vocab.id)
    assert_selector ".lp-qs-detail.is-open", wait: 5
    flash = @host.practice_tasks.find_by!(title: "Flashcards")
    page.execute_script(<<~JS)
      const el = document.querySelector(".lp-qs-obj__check");
      el?.scrollIntoView({ block: "center" });
      el?.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
    JS
    sleep 0.4
    assert_not flash.reload.completed?, "Quest Space checkbox must stay read-only"

    find(".lp-qs-detail__add-input", visible: :all).set("Review verbs")
    find(".lp-qs-detail__add-btn", visible: :all).click
    assert_selector ".lp-qs-obj__text[value='Review verbs']", visible: :all, wait: 5
    assert @host.practice_tasks.exists?(title: "Review verbs")

    page.save_screenshot("/opt/cursor/artifacts/screenshots/quest-space-add-btn-mobile.png")
  end

  test "New Quest Cancel closes the portaled floating card" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @lang.id)
    assert_selector ".lp-qs-new__btn", text: /New Quest/i, wait: 5

    page.execute_script(<<~JS)
      const trigger = document.querySelector(".lp-qs-new__btn");
      trigger?.scrollIntoView({ block: "center" });
      trigger?.click();
    JS
    assert_selector "body > .lp-rpg-float-create:not([hidden])", wait: 3
    assert_selector ".lp-rpg-float-create__heading", text: /New Quest/i

    find("body > .lp-rpg-float-create .lp-rpg-float-create__btn.is-cancel", text: /Cancel/i).click
    assert_no_selector "body > .lp-rpg-float-create:not([hidden])", wait: 3
  end
end
