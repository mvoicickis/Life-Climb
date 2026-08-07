# frozen_string_literal: true

require "application_system_test_case"

# Climb path titles keep the full string in the title attribute; long names
# may ellipsize in the pin card without losing the accessible name.
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

  test "long section title keeps full name on tall phone" do
    section = create_section!(LONG_TITLE)
    assert_section_title_named(section, LONG_TITLE, 390, 844)
  end

  test "long section title keeps full name on short phone" do
    section = create_section!(LONG_TITLE)
    assert_section_title_named(section, LONG_TITLE, 390, 568)
  end

  test "short section title keeps full name on tall phone" do
    section = create_section!(SHORT_TITLE)
    assert_section_title_named(section, SHORT_TITLE, 390, 844)
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

  def assert_section_title_named(section, expected_text, width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    sign_in_user!

    within(".lp-dash-nav") { click_link "Mountain" }
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: section.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase", wait: 5
    assert_selector ".lp-climb-path__node.is-selected .lp-climb-path__title", visible: :all, wait: 5

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector(".lp-climb-path__node.is-selected .lp-climb-path__title");
        if (!el) return { ok: false };
        const r = el.getBoundingClientRect();
        return {
          ok: true,
          text: (el.textContent || "").trim(),
          titleAttr: el.getAttribute("title") || "",
          width: r.width
        };
      })()
    JS
    assert metrics["ok"], "climb path title missing at #{width}x#{height}"
    assert_equal expected_text, metrics["titleAttr"]
    assert_operator metrics["width"].to_f, :>=, 80.0
    assert_includes metrics["text"], expected_text.split.first
  end
end
