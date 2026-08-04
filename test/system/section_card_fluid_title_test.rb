# frozen_string_literal: true

require "application_system_test_case"

# Project Sections titles sit on a full-width row under icon/badge chrome,
# so realistic titles stay readable (2-line clamp only for extreme length).
class SectionCardFluidTitleTest < ApplicationSystemTestCase
  LONG_TITLE = "Start: Make LifePoints Successsull"
  SHORT_TITLE = "Learn German"

  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship the product",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Design",
      closer_percent: 40,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "MVP path", position: 0
    )
  end

  test "long section title is fully readable on tall phone" do
    section = create_section!(LONG_TITLE)
    assert_section_title_readable(section, LONG_TITLE, 390, 844)
  end

  test "long section title is fully readable on short phone" do
    section = create_section!(LONG_TITLE)
    assert_section_title_readable(section, LONG_TITLE, 390, 568)
  end

  test "short section title is fully readable on tall phone" do
    section = create_section!(SHORT_TITLE)
    assert_section_title_readable(section, SHORT_TITLE, 390, 844)
  end

  private

  def create_section!(title)
    section = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: title, position: 0
    )
    practice_leaf_for!(section).children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Design", scheduled_on: Date.current, position: 0
    )
    section
  end

  def sign_in_user!
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5
  end

  def title_metrics
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector(".lp-rpg-section-card.is-selected .lp-rpg-section-card__title");
        const card = document.querySelector(".lp-rpg-section-card.is-selected");
        const link = document.querySelector(".lp-rpg-section-card.is-selected .lp-rpg-section-card__link");
        const meta = document.querySelector(".lp-rpg-section-card.is-selected .lp-rpg-section-card__meta");
        if (!el || !card || !link) return { ok: false, reason: "missing" };
        const cs = getComputedStyle(el);
        const r = el.getBoundingClientRect();
        const cardR = card.getBoundingClientRect();
        const linkCs = getComputedStyle(link);
        // Detect line-clamp / overflow truncation: clipped box is shorter than full text.
        const truncated = el.scrollHeight > el.clientHeight + 1;
        return {
          ok: true,
          text: (el.textContent || "").trim(),
          titleAttr: el.getAttribute("title") || "",
          fontSize: cs.fontSize,
          whiteSpace: cs.whiteSpace,
          webkitLineClamp: cs.webkitLineClamp || cs.lineClamp || "",
          linkFlexDirection: linkCs.flexDirection,
          hasMetaRow: !!meta,
          width: r.width,
          height: r.height,
          scrollHeight: el.scrollHeight,
          clientHeight: el.clientHeight,
          truncated,
          cardHeight: cardR.height,
          viewport: [window.innerWidth, window.innerHeight]
        };
      })()
    JS
  end

  def assert_section_title_readable(section, expected_text, width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    sign_in_user!

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: section.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5
    assert_selector ".lp-rpg-section-card.is-selected .lp-rpg-section-card__title", visible: :all, wait: 5
    assert_selector ".lp-rpg-section-card.is-selected .lp-rpg-section-card__meta", visible: :all, wait: 5

    # Capybara visible text must include the full title (not a mid-string ellipsis fragment).
    assert_text expected_text

    metrics = title_metrics
    assert metrics["ok"], "section title missing at #{width}x#{height}: #{metrics.inspect}"
    assert_equal expected_text, metrics["text"]
    assert_equal expected_text, metrics["titleAttr"]
    assert metrics["hasMetaRow"], "expected icon/badge meta row above title: #{metrics.inspect}"
    assert_equal "column", metrics["linkFlexDirection"].to_s,
                 "title must sit under chrome in a column link: #{metrics.inspect}"
    refute_equal "nowrap", metrics["whiteSpace"].to_s
    assert_includes %w[2], metrics["webkitLineClamp"].to_s

    # Full-width title column (not the old ~70px squeeze beside icon+badge).
    assert_operator metrics["width"].to_f, :>=, 120.0,
                    "title column still too narrow at #{width}x#{height}: #{metrics.inspect}"

    # For these realistic lengths, 2-line clamp must not clip — text is fully painted.
    refute metrics["truncated"],
           "title still visually truncated at #{width}x#{height}: #{metrics.inspect}"

    assert_operator metrics["cardHeight"].to_f, :>=, 8.0 * 16,
                    "card too short for stacked chrome+title at #{width}x#{height}: #{metrics.inspect}"
  end
end
