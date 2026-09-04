# frozen_string_literal: true

require "application_system_test_case"

class ProjectSectionsMenuPropagationTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship the MVP",
      ideal_scene: "App live", current_reality: "Building", next_win: "Launch",
      today_mission: "Design", closer_percent: 40, route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "MVP path", position: 0
    )
    @section = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "MVP", position: 0
    )
    @other = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Launch", position: 1
    )
  end

  test "menu button hit area does not navigate the section card" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    path = life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @section.id)
    visit path
    open_mountain_list_fallback!
    assert_selector "#climb-path-project-#{@section.id} .lp-climb-path__menu-btn", visible: :all, wait: 5
    page.execute_script(<<~JS)
      document.querySelector('#climb-path-project-#{@section.id}')?.scrollIntoView({ block: 'center' });
    JS

    before = page.current_path

    menu_span = find("#climb-path-project-#{@section.id} .lp-climb-path__menu-btn span", visible: :all)
    page.execute_script("arguments[0].click()", menu_span.native)
    assert_selector "#climb-path-project-#{@section.id} .lp-climb-path__menu:not([hidden])", visible: :all, wait: 3
    assert_equal before, page.current_path

    page.send_keys(:escape)
    assert_no_selector "#climb-path-project-#{@section.id} .lp-climb-path__menu:not([hidden])", visible: :all, wait: 3

    btn = find("#climb-path-project-#{@section.id} .lp-climb-path__menu-btn", visible: :all)
    page.execute_script(<<~JS, btn.native)
      const el = arguments[0];
      const r = el.getBoundingClientRect();
      const x = r.right - 2;
      const y = r.top + r.height / 2;
      const target = document.elementFromPoint(x, y);
      target?.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, clientX: x, clientY: y }));
    JS
    assert_selector "#climb-path-project-#{@section.id} .lp-climb-path__menu:not([hidden])", visible: :all, wait: 3
    assert_equal before, page.current_path

    # 3) Choosing Edit must not navigate
    page.execute_script(<<~JS)
      document.querySelector('#climb-path-project-#{@section.id} .lp-climb-path__menu:not([hidden]) .lp-climb-path__menu-item:not(.is-danger)')?.click();
    JS
    assert_selector "dialog[open] .lp-strategy-sheet__title", text: /Edit Camp/i, wait: 3
    assert_equal before, page.current_path
    assert_includes page.current_url, "focus_id=#{@section.id}"
    FileUtils.mkdir_p("/opt/cursor/artifacts/screenshots")
    page.save_screenshot("/opt/cursor/artifacts/screenshots/project-sections-menu-propagation.png")
  end
end
