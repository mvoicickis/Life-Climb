# frozen_string_literal: true

require "application_system_test_case"

class PlanCardMenuTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan_a = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Alpha Path", position: 0
    )
    @plan_b = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Beta Path", position: 1
    )
    [ @plan_a, @plan_b ].each_with_index do |plan, idx|
      project = plan.children.create!(
        user: @user, life_area: @journey.life_area, life_journey: @journey,
        horizon: "project", title: "Camp #{idx}", position: 0
      )
      project_leaf = practice_leaf_for!(project)
      project_leaf.children.create!(
        user: @user, life_area: @journey.life_area, life_journey: @journey,
        horizon: "day", title: "Fight #{idx}", scheduled_on: Date.current, position: 0
      )
    end
  end

  test "plan card menu opens, closes on outside and escape, and stays single-open" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"

    assert @journey.present?, "expected an onboarded journey"
    within(".lp-dash-nav") { click_link "Mountain" }

    assert_selector "#strategy-world", wait: 5
    assert_selector ".lp-rpg-plan-rail"
    assert_selector ".lp-rpg-path", text: /Alpha Path/
    assert_selector ".lp-rpg-path__menu-btn", minimum: 2

    buttons = all(".lp-rpg-path__menu-btn")
    first_btn = buttons[0]
    second_btn = buttons[1]

    first_btn.click
    assert_selector ".lp-rpg-path__menu:not([hidden])", text: /Edit Plan/
    assert_selector ".lp-rpg-path__menu:not([hidden])", text: /Delete Plan/
    assert_selector ".lp-rpg-path__menu:not([hidden])", count: 1

    page.execute_script("document.elementFromPoint(4, 4).dispatchEvent(new PointerEvent('pointerdown', {bubbles:true}))")
    assert_no_selector ".lp-rpg-path__menu:not([hidden])"

    first_btn.click
    assert_selector ".lp-rpg-path__menu:not([hidden])", count: 1
    page.send_keys(:escape)
    assert_no_selector ".lp-rpg-path__menu:not([hidden])"

    first_btn.click
    assert_selector ".lp-rpg-path__menu:not([hidden])", count: 1
    second_btn.click
    assert_selector ".lp-rpg-path__menu:not([hidden])", count: 1
    assert_equal "true", second_btn["aria-expanded"]
    assert_equal "false", first_btn["aria-expanded"]
  end

  test "edit plan opens existing rename form, saves, and returns to mountain" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    within(".lp-dash-nav") { click_link "Mountain" }

    assert_selector ".lp-rpg-path", text: /Alpha Path/
    find(".lp-rpg-path__menu-btn", match: :first).click
    click_button "Edit Plan"

    assert_selector "dialog.lp-strategy-sheet[open]"
    within("dialog.lp-strategy-sheet[open]") do
      assert_field "plan-edit-title-#{@plan_a.id}", with: "Alpha Path"
      fill_in "plan-edit-title-#{@plan_a.id}", with: "Renamed Path"
      click_button "Save Changes"
    end

    assert_selector "#strategy-world", wait: 5
    assert_selector ".lp-rpg-path.is-focus", text: /Renamed Path/
    assert_equal "Renamed Path", @plan_a.reload.title
    assert_no_selector "dialog.lp-strategy-sheet[open]"
  end

  test "delete plan requires confirmation then removes plan and keeps sibling focused" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    within(".lp-dash-nav") { click_link "Mountain" }

    assert_selector ".lp-rpg-path", text: /Alpha Path/
    find(".lp-rpg-path__menu-btn", match: :first).click
    assert_selector ".lp-rpg-path__menu:not([hidden])", wait: 3
    page.execute_script(<<~JS)
      document.querySelector('.lp-rpg-path__menu:not([hidden]) .lp-rpg-path__menu-item.is-danger')?.click();
    JS

    assert_selector "dialog.lp-strategy-sheet[open]", text: /Delete Plan\?/
    assert_selector "dialog.lp-strategy-sheet[open]", text: /cannot be undone/i
    within("dialog.lp-strategy-sheet[open]") { click_button "Cancel" }
    assert_no_selector "dialog.lp-strategy-sheet[open]"
    assert StrategyGoal.exists?(@plan_a.id)
    assert_selector ".lp-rpg-path", text: /Alpha Path/

    find(".lp-rpg-path__menu-btn", match: :first).click
    assert_selector ".lp-rpg-path__menu:not([hidden])", wait: 3
    page.execute_script(<<~JS)
      document.querySelector('.lp-rpg-path__menu:not([hidden]) .lp-rpg-path__menu-item.is-danger')?.click();
    JS
    within("dialog.lp-strategy-sheet[open]") { click_button "Delete" }

    assert_selector "#strategy-world", wait: 5
    assert_no_selector ".lp-rpg-path", text: /Alpha Path/
    assert_selector ".lp-rpg-path.is-focus", text: /Beta Path/
    assert_not StrategyGoal.exists?(@plan_a.id)
  end
end
