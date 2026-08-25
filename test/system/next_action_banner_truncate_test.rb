# frozen_string_literal: true

require "application_system_test_case"

# Today V2 drops the next-action banner; long battle titles wrap in the row list.
class NextActionBannerTruncateTest < ApplicationSystemTestCase
  LONG_TODO = "Rewrite the quarterly stakeholder update deck for board review"

  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    page.driver.browser.manage.window.resize_to(390, 844)
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 0, 0)

    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first

    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan",
      title: "Get interviews", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Improve apps", position: 0
    )
    leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: leaf, horizon: "day",
      title: LONG_TODO, scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    dismiss_onboarding_missions!(@user)
    clear_setup_gap!
  end

  teardown { travel_back }

  test "long battle title wraps on Today V2 row without next-action banner" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav.is-today-v2", wait: 5

    visit dashboard_path
    assert_today_v2_shell!
    assert_no_selector ".lp-dash-next"
    assert_no_selector "[data-commitment-progress]"
    assert_battle_row!(title: LONG_TODO, camp: "Improve apps")
    assert_row_title_wraps!

    visit life_journey_path(@journey)
    assert_no_selector ".lp-dash-next"
  end

  private

  def practice_leaf_for!(camp)
    camp
  end

  def clear_setup_gap!
    have = @user.habits.active.on_home.count
    (have + 1).upto(@journey.commitment_habit_count.to_i) do |n|
      @user.habits.create!(
        name: "Habit #{n}", unit: "times", points: 5, frequency: "daily",
        active: true, show_on_home: true, quantity_checkin: false
      )
    end
    need = @journey.commitment_battle_count.to_i
    todos = @user.daily_todos.for_day(Date.current).ordered.to_a
    while todos.size < need
      todos << @user.daily_todos.create!(
        title: "Setup fight #{todos.size + 1}",
        scheduled_on: Date.current,
        aspect_key: "career",
        start_time: "09:00",
        end_time: "10:00",
        position: 500 + todos.size
      )
    end
    @user.daily_todos.for_day(Date.current).find_each do |todo|
      next if todo.timed?

      todo.update!(start_time: "09:00", end_time: "10:00")
    end
  end

  def assert_row_title_wraps!
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const title = document.querySelector('.lp-today-v2-row__title');
        if (!title) return null;
        const ts = getComputedStyle(title);
        return {
          titleTextOverflow: ts.textOverflow,
          titleWhiteSpace: ts.whiteSpace,
          titleScrollWider: title.scrollWidth > title.clientWidth + 1,
          titleText: title.textContent.trim(),
          vw: window.innerWidth
        };
      })()
    JS

    assert metrics.present?, "Today V2 battle row title missing"
    assert_equal "normal", metrics["titleWhiteSpace"]
    refute_equal "ellipsis", metrics["titleTextOverflow"]
    refute metrics["titleScrollWider"], "title should wrap, not overflow with ellipsis"
    assert_includes metrics["titleText"], "board review"
  end
end
