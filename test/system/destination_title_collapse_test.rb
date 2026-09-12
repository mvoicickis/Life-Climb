# frozen_string_literal: true

require "application_system_test_case"

# Terraced HUD goal plaque: title must stay readable and in view on short and tall phones.
class DestinationTitleCollapseTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Become a Rails developer",
      ideal_scene: "Shipping features",
      current_reality: "Learning",
      next_win: "First PR",
      today_mission: "Write one test",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    plan = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Skills path", position: 0
    )
    camp = plan.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "Rails camp", position: 0
    )
    practice_leaf_for!(camp).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "day", title: "Write one test", scheduled_on: Date.current, position: 0
    )
    @plan = plan
  end

  test "destination title stays readable on tall iPhone viewport" do
    assert_goal_plaque_readable(390, 844)
  end

  test "destination title stays readable on short phone viewport" do
    assert_goal_plaque_readable(390, 568)
  end

  private

  def assert_goal_plaque_readable(width, height)
    page.driver.browser.manage.window.resize_to(width, height)

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 8

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 10
    assert_selector "#mountain-trail.lp-trail.is-v4", wait: 10
    assert_selector ".lp-trail__goal-plaque", visible: :all, wait: 5
    assert_selector ".lp-trail__goal-title", text: /Become a Rails developer/i, visible: :all, wait: 5

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const title = document.querySelector(".lp-trail__goal-title");
        const plaque = document.querySelector(".lp-trail__goal-plaque");
        if (!title || !plaque) return { ok: false, reason: "missing nodes" };

        const titleStyle = getComputedStyle(title);
        const titleRect = title.getBoundingClientRect();
        const plaqueRect = plaque.getBoundingClientRect();
        const range = document.createRange();
        range.selectNodeContents(title);
        const lineWidths = Array.from(range.getClientRects()).map((rect) => rect.width);
        const maxLineWidth = lineWidths.length ? Math.max(...lineWidths) : titleRect.width;

        return {
          ok: true,
          text: (title.textContent || "").trim(),
          titleW: titleRect.width,
          titleH: titleRect.height,
          plaqueW: plaqueRect.width,
          plaqueH: plaqueRect.height,
          inView: plaqueRect.bottom > 0 && plaqueRect.top < window.innerHeight,
          maxLineWidth,
          clientWidth: title.clientWidth,
          lineClamp: titleStyle.webkitLineClamp,
          viewport: [window.innerWidth, window.innerHeight]
        };
      })()
    JS

    assert metrics["ok"], "Goal plaque metrics missing: #{metrics.inspect}"
    assert_match(/Become a Rails developer/i, metrics["text"].to_s)
    assert_operator metrics["titleW"], :>=, 72,
                    "goal title too narrow at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["titleH"], :>=, 12,
                    "goal title has no visible height at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["plaqueH"], :>=, 36,
                    "goal plaque collapsed at #{width}x#{height}: #{metrics.inspect}"
    assert metrics["inView"],
           "goal plaque not in viewport at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["maxLineWidth"].to_f, :<=, metrics["clientWidth"].to_f + 1.0,
                    "goal title overflows plaque at #{width}x#{height}: #{metrics.inspect}"
    assert_no_selector ".lp-rpg-destination-carousel__stage"
    assert_no_selector ".lp-rpg-destination-carousel__arrow"
  end
end
