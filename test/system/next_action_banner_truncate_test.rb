# frozen_string_literal: true

require "application_system_test_case"

# Long companion-voice headlines must wrap — never clip mid-word with ellipsis.
class NextActionBannerTruncateTest < ApplicationSystemTestCase
  LONG_TODO = "Rewrite the quarterly stakeholder update deck for board review"
  LONG_HEADLINE =
    "⚔️ Finish “#{LONG_TODO}” and the trail lights up."

  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    page.driver.browser.manage.window.resize_to(390, 844)
    # complete_battle yields to battle_overdue after 18:00 — pin morning for a stable key.
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
    clear_setup_gap!
  end

  teardown { travel_back }

  test "long complete_battle headline wraps on Today with commitment progress" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    with_fixed_next_action_headline(LONG_HEADLINE) do
      visit dashboard_path
      assert_selector ".lp-dash-next[data-next-action-key=complete_battle]", wait: 5
      assert_selector "[data-commitment-progress]", wait: 5
      assert_no_selector ".lp-dash-next a.lp-cta"
      assert_banner_wraps!(placement: "Today")

      visit life_journey_path(@journey)
      assert_no_selector ".lp-dash-next"
    end
  end

  private

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

  def with_fixed_next_action_headline(headline)
    singleton = Strategy::NextAction::Copy.singleton_class
    original = singleton.instance_method(:headline_for)
    singleton.define_method(:headline_for) { |**_| headline }
    yield
  ensure
    singleton.define_method(:headline_for, original)
  end

  def assert_banner_wraps!(placement:)
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const banner = document.querySelector('.lp-dash-next');
        const title = document.querySelector('.lp-dash-next__title');
        const progress = document.querySelector('.lp-dash-next__progress');
        if (!banner || !title || !progress) return null;
        const bs = getComputedStyle(banner);
        const ts = getComputedStyle(title);
        const br = banner.getBoundingClientRect();
        const pr = progress.getBoundingClientRect();
        return {
          flexWrap: bs.flexWrap,
          bannerMinWidth: bs.minWidth,
          titleTextOverflow: ts.textOverflow,
          titleWhiteSpace: ts.whiteSpace,
          titleScrollWider: title.scrollWidth > title.clientWidth + 1,
          titleText: title.textContent.trim(),
          progressLeft: pr.left,
          progressRight: pr.right,
          bannerRight: br.right,
          bannerLeft: br.left,
          vw: window.innerWidth
        };
      })()
    JS

    assert metrics.present?, "#{placement}: NextAction banner missing"
    assert_equal "wrap", metrics["flexWrap"], "#{placement}: banner should allow wrap"
    assert_equal "0px", metrics["bannerMinWidth"], "#{placement}: banner min-width"
    assert_operator metrics["bannerRight"] - metrics["bannerLeft"], :<=, metrics["vw"] + 1
    assert_equal "normal", metrics["titleWhiteSpace"]
    refute_equal "ellipsis", metrics["titleTextOverflow"]
    refute metrics["titleScrollWider"], "#{placement}: title should wrap, not overflow with ellipsis"
    assert_includes metrics["titleText"], "board review"
    assert_operator metrics["progressLeft"], :>=, metrics["bannerLeft"] - 1
    assert_operator metrics["progressRight"], :<=, metrics["bannerRight"] + 1
    assert_operator metrics["progressRight"], :<=, metrics["vw"] + 1
  end
end
