# frozen_string_literal: true

require "application_system_test_case"

# Quest objectives under ⋮ → Objectives mutate via Turbo Streams (sheet stays open).
class PracticeTasksTurboStreamSystemTest < ApplicationSystemTestCase
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
    @vocab = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Vocabulary", position: 0
    )
    @host = Strategy::EnsureFolderQuest.call(folder: @vocab)
    @host.practice_tasks.create!(user: @user, title: "Learn 15 new words", position: 0)
    @host.practice_tasks.create!(user: @user, title: "Flashcards", position: 1)
  end

  test "add rename delete objectives via turbo streams without leaving the sheet" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @vocab.id)
    open_project_objectives(@vocab)
    within("dialog#section-objectives-#{@vocab.id}") do
      open_mountain_list_fallback!
      assert_selector ".lp-climb-path__quest-title", text: /Vocabulary/i
      assert_selector "turbo-frame#quest_objectives_#{@vocab.id}", wait: 5
      assert_selector "#quest_progress_#{@vocab.id}", text: /0 \/ 2 objectives done/i

      find(".lp-climb-path__quest-add-input", visible: :all).set("Review verbs")
      find(".lp-climb-path__quest-add-btn", visible: :all).click
      assert_selector ".lp-qs-obj__text[value='Review verbs']", visible: :all, wait: 5
      assert_selector ".lp-climb-path__quest", text: /Vocabulary/i
      assert_selector "turbo-frame#quest_objectives_#{@vocab.id}"
      assert_selector "#quest_progress_#{@vocab.id}", text: /0 \/ 3 objectives done/i, wait: 5
    end
    assert @host.practice_tasks.exists?(title: "Review verbs")

    within("dialog#section-objectives-#{@vocab.id}") do
      field = find(".lp-qs-obj__text[value='Review verbs']", visible: :all)
      field.set("Review verbs daily")
      field.send_keys(:tab)
      assert_selector ".lp-qs-obj__text[value='Review verbs daily']", visible: :all, wait: 5
    end
    assert_equal "Review verbs daily", @host.practice_tasks.find_by!(title: "Review verbs daily").title

    within("dialog#section-objectives-#{@vocab.id}") do
      row = find("[data-quest-space-row][data-title='Review verbs daily']", visible: :all)
      row.find(".lp-qs-obj__trash", visible: :all).click
      assert_no_selector ".lp-qs-obj__text[value='Review verbs daily']", wait: 5
      assert_selector "turbo-frame#quest_objectives_#{@vocab.id}"
      assert_selector "#quest_progress_#{@vocab.id}", text: /0 \/ 2 objectives done/i, wait: 5
    end
    assert_not @host.practice_tasks.exists?(title: "Review verbs daily")
  end
end
