# frozen_string_literal: true

require "application_system_test_case"

# V4 destination title lives on the peak pennant (.lp-trail__peak-title).
# contenteditable forces white-space: pre in Chrome, so we assert layout fit
# (no horizontal overflow, 2-line clamp) rather than white-space: nowrap.
class FluidHeroTitleTest < ApplicationSystemTestCase
  LONG_LATVIAN_TITLE = "Profesionāla Rails izstrādātāja karjeras ceļš"

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
    @plan = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Skills path", position: 0
    )
    camp = @plan.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "project", title: "Rails camp", position: 0
    )
    practice_leaf_for!(camp).children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "day", title: "Write one test", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @journey.life_area)
    dismiss_onboarding_missions!(@user)
  end

  test "destination title is fluid and untruncated on tall phone" do
    assert_destination_fluid_title(390, 844, "Become a Rails developer")
  end

  test "destination title is fluid and untruncated on short phone" do
    assert_destination_fluid_title(390, 568, "Become a Rails developer")
  end

  test "long Latvian destination title fits pennant on narrow phone" do
    @goal.update!(title: LONG_LATVIAN_TITLE)
    assert_destination_fluid_title(360, 640, LONG_LATVIAN_TITLE)
  end

  test "today V2 battlefield renders on tall phone" do
    assert_today_v2_battlefield(390, 844)
  end

  test "today V2 battlefield renders on short phone" do
    assert_today_v2_battlefield(390, 568)
  end

  private

  def practice_leaf_for!(camp)
    camp
  end

  def sign_in_user!
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
  end

  def peak_title_metrics
    page.evaluate_script(<<~JS)
      (() => {
        const title = document.querySelector(".lp-trail__peak-title");
        const pennant = title?.closest(".lp-trail__pennant");
        if (!title || !pennant) return { ok: false, reason: "missing" };
        const cs = getComputedStyle(title);
        const tr = title.getBoundingClientRect();
        const pr = pennant.getBoundingClientRect();
        const range = document.createRange();
        range.selectNodeContents(title);
        const lineWidths = Array.from(range.getClientRects()).map((rect) => rect.width);
        const maxLineWidth = lineWidths.length ? Math.max(...lineWidths) : tr.width;
        return {
          ok: true,
          text: (title.textContent || "").trim(),
          fontSize: cs.fontSize,
          lineClamp: cs.webkitLineClamp,
          maxWidth: cs.maxWidth,
          maxLineWidth,
          lineCount: lineWidths.length,
          clientWidth: title.clientWidth,
          width: tr.width,
          height: tr.height,
          pennantHeight: pr.height,
          viewport: [window.innerWidth, window.innerHeight]
        };
      })()
    JS
  end

  def assert_peak_title_ok(metrics, expected_text, width, height)
    assert metrics["ok"], "title missing at #{width}x#{height}: #{metrics.inspect}"
    assert_equal expected_text, metrics["text"]
    assert_equal "2", metrics["lineClamp"].to_s,
                 "peak title should clamp to 2 lines at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["maxLineWidth"].to_f, :<=, metrics["clientWidth"].to_f + 1.0,
                    "peak title line overflows horizontally at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["width"].to_f, :>=, 80.0,
                    "title too narrow at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["height"].to_f, :>=, 16.0,
                    "title has no height at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["pennantHeight"].to_f, :>=, metrics["height"].to_f + 20.0,
                    "pennant ribbon shorter than title at #{width}x#{height}: #{metrics.inspect}"
    px = metrics["fontSize"].to_s.to_f
    assert_operator px, :>=, 14.0,
                    "font-size below peak floor at #{width}x#{height}: #{metrics.inspect}"
  end

  def assert_destination_fluid_title(width, height, expected_text)
    page.driver.browser.manage.window.resize_to(width, height)
    sign_in_user!
    assert_selector ".lp-dash-nav", wait: 8
    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 10
    assert_no_selector ".lp-first-climb-shell", wait: 2
    assert_selector "#mountain-trail.lp-trail.is-v4", wait: 10
    assert_selector ".lp-trail__peak-title", text: /#{Regexp.escape(expected_text.split.first)}/i, visible: :all, wait: 5
    metrics = peak_title_metrics
    assert_peak_title_ok(metrics, expected_text, width, height)
  end

  def assert_today_v2_battlefield(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    sign_in_user!
    assert_selector ".lp-dash-nav.is-today-v2", wait: 8
    within(".lp-dash-nav") { click_link "Today" } if page.has_css?(".lp-dash-nav__link", text: /Today/i)
    assert_today_v2_shell!
    assert_selector ".lp-today-v2-header__avatar-img", visible: :all
    assert_selector ".lp-today-v2-field", visible: :all
    assert_battle_row!(title: "Write one test", camp: "Rails camp")
    assert_no_selector ".lp-dash-climb"
    assert_no_legacy_today_shell!
  end
end
