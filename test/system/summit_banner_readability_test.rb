# frozen_string_literal: true

require "application_system_test_case"

# Summit goal pennant: readable type, grows with copy, stays clear of ridge "more camps" chip.
class SummitBannerReadabilityTest < ApplicationSystemTestCase
  LONG_GOAL = "Learn German to B1 level"

  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: LONG_GOAL,
      ideal_scene: "Conversational",
      current_reality: "Studying",
      next_win: "A2 exam",
      today_mission: "Vocabulary drill",
      closer_percent: 30,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Language path", position: 0
    )
    %w[Basics Grammar Listening Speaking].each_with_index do |title, i|
      @plan.children.create!(
        user: @user, life_area: @journey.life_area, life_journey: @journey,
        horizon: "project", title: title, position: i
      )
    end
  end

  test "long goal pennant readable at 320px without overlapping more camps chip" do
    assert_summit_pennant_ok(320, 568)
  end

  test "long goal pennant readable at 360px without overlapping more camps chip" do
    assert_summit_pennant_ok(360, 568)
  end

  test "long goal pennant readable at 390px short phone without overlapping more camps chip" do
    assert_summit_pennant_ok(390, 568)
  end

  private

  def assert_summit_pennant_ok(width, height)
    page.driver.browser.manage.window.resize_to(width, height)

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 8

    visit life_journey_path(@journey.reload, goal_id: @goal.id, plan_id: @plan.id)
    assert_selector "#mountain-trail.lp-trail.is-v4", wait: 10
    assert_selector ".lp-trail-more", visible: :all, wait: 5
    assert_selector ".lp-trail__summit-banner", visible: :all, wait: 5

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const banner = document.querySelector(".lp-trail__summit-banner");
        const title = banner?.querySelector(".lp-trail__goal-title");
        const more = document.querySelector(".lp-trail-more");
        const campTitle = document.querySelector(".lp-trail-camp__title");
        if (!banner || !title || !more || !campTitle) {
          return { ok: false, reason: "missing nodes" };
        }

        const titleStyle = getComputedStyle(title);
        const campStyle = getComputedStyle(campTitle);
        const bannerRect = banner.getBoundingClientRect();
        const moreRect = more.getBoundingClientRect();
        const range = document.createRange();
        range.selectNodeContents(title);
        const lineWidths = Array.from(range.getClientRects()).map((rect) => rect.width);
        const maxLineWidth = lineWidths.length ? Math.max(...lineWidths) : title.getBoundingClientRect().width;

        const gap = 4;
        const overlaps = !(
          bannerRect.right < moreRect.left + gap ||
          bannerRect.left > moreRect.right - gap ||
          bannerRect.bottom < moreRect.top + gap ||
          bannerRect.top > moreRect.bottom - gap
        );

        return {
          ok: true,
          text: (title.textContent || "").trim(),
          bannerW: bannerRect.width,
          bannerH: bannerRect.height,
          summitFontPx: parseFloat(titleStyle.fontSize) || 0,
          campFontPx: parseFloat(campStyle.fontSize) || 0,
          lineClamp: titleStyle.webkitLineClamp,
          lineCount: lineWidths.length,
          maxLineWidth,
          clientWidth: title.clientWidth,
          overlapsMore: overlaps,
          inView: bannerRect.bottom > 0 && bannerRect.top < window.innerHeight,
          viewport: [window.innerWidth, window.innerHeight]
        };
      })()
    JS

    assert metrics["ok"], "Summit metrics missing at #{width}x#{height}: #{metrics.inspect}"
    assert_match(/Learn German to B1 level/i, metrics["text"].to_s)
    assert_equal "2", metrics["lineClamp"].to_s,
                 "goal should clamp to 2 lines at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["lineCount"].to_i, :<=, 2,
                    "goal should use at most 2 lines at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["summitFontPx"].to_f, :>=, metrics["campFontPx"].to_f,
                    "summit label should be at least camp caption size at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["bannerW"].to_f, :>=, 80.0,
                    "summit pennant too narrow at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["bannerH"].to_f, :>=, 36.0,
                    "summit pennant collapsed at #{width}x#{height}: #{metrics.inspect}"
    assert metrics["inView"],
           "summit pennant not in viewport at #{width}x#{height}: #{metrics.inspect}"
    assert_not metrics["overlapsMore"],
               "summit pennant overlaps more-camps chip at #{width}x#{height}: #{metrics.inspect}"
    assert_operator metrics["maxLineWidth"].to_f, :<=, metrics["clientWidth"].to_f + 1.0,
                    "goal line overflows pennant at #{width}x#{height}: #{metrics.inspect}"
  end
end
