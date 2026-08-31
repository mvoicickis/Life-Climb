# frozen_string_literal: true

require "application_system_test_case"

# V4 camp names live in aria-label; a short caption sits under every tent.
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
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox")
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

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: section.id)
    assert_selector "#strategy-world.lp-rpg.is-focus-phase.is-v4-phone", wait: 5
    assert_selector "#trail-camp-#{section.id}", visible: :all, wait: 5
    label = page.find("#trail-camp-#{section.id}", visible: :all)["aria-label"]
    assert_equal expected_text, label

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("#trail-camp-#{section.id}");
        if (!el) return { ok: false };
        const r = el.getBoundingClientRect();
        const tent = el.querySelector(".lp-trail-camp__tent");
        const caption = el.querySelector(".lp-trail-camp__caption .lp-trail-camp__title");
        return {
          ok: true,
          hasTent: Boolean(tent),
          label: el.getAttribute("aria-label") || "",
          caption: caption ? (caption.textContent || "").trim() : "",
          width: r.width
        };
      })()
    JS
    assert metrics["ok"], "trail camp tent missing at #{width}x#{height}"
    assert metrics["hasTent"]
    assert_equal expected_text, metrics["label"]
    assert_operator metrics["width"].to_f, :>=, 40.0
    assert_equal expected_text.truncate(MountainTrailHelper::CAMP_TENT_TITLE_LIMIT), metrics["caption"]
  end
end
