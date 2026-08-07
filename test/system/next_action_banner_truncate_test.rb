# frozen_string_literal: true

require "application_system_test_case"

# Long companion-voice headlines must truncate — not shove the CTA off-screen.
class NextActionBannerTruncateTest < ApplicationSystemTestCase
  LONG_TODO = "Rewrite the quarterly stakeholder update deck for board review"
  LONG_HEADLINE =
    "⚔️ Finish “#{LONG_TODO}” and the trail lights up."

  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    page.driver.browser.manage.window.resize_to(390, 844)

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
  end

  test "long complete_battle headline truncates on Today and Mountain without clipping CTA" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    with_fixed_next_action_headline(LONG_HEADLINE) do
      visit dashboard_path
      assert_selector ".lp-dash-next[data-next-action-key=complete_battle]", wait: 5
      assert_banner_truncates!(placement: "Today")

      visit life_journey_path(@journey)
      assert_selector ".lp-dash-next[data-next-action-key=complete_battle]", wait: 5
      assert_banner_truncates!(placement: "Mountain")
    end
  end

  private

  def with_fixed_next_action_headline(headline)
    singleton = Strategy::NextAction::Copy.singleton_class
    original = singleton.instance_method(:headline_for)
    singleton.define_method(:headline_for) { |**_| headline }
    yield
  ensure
    singleton.define_method(:headline_for, original)
  end

  def assert_banner_truncates!(placement:)
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const banner = document.querySelector('.lp-dash-next');
        const title = document.querySelector('.lp-dash-next__title');
        const cta = document.querySelector('.lp-dash-next a.lp-cta');
        if (!banner || !title || !cta) return null;
        const bs = getComputedStyle(banner);
        const ts = getComputedStyle(title);
        const cs = getComputedStyle(cta);
        const br = banner.getBoundingClientRect();
        const cr = cta.getBoundingClientRect();
        return {
          flexWrap: bs.flexWrap,
          bannerMinWidth: bs.minWidth,
          bannerMaxWidth: bs.maxWidth,
          bannerWidth: bs.width,
          titleFlex: ts.flex,
          titleFlexGrow: ts.flexGrow,
          titleFlexShrink: ts.flexShrink,
          titleFlexBasis: ts.flexBasis,
          titleMinWidth: ts.minWidth,
          titleOverflow: ts.overflow,
          titleTextOverflow: ts.textOverflow,
          titleWhiteSpace: ts.whiteSpace,
          titleScrollWider: title.scrollWidth > title.clientWidth + 1,
          ctaMinHeight: parseFloat(cs.minHeight),
          ctaRight: cr.right,
          ctaLeft: cr.left,
          bannerRight: br.right,
          bannerLeft: br.left,
          vw: window.innerWidth
        };
      })()
    JS

    assert metrics.present?, "#{placement}: NextAction banner missing"
    assert_equal "nowrap", metrics["flexWrap"], "#{placement}: must stay single-row"
    assert_equal "0px", metrics["bannerMinWidth"], "#{placement}: banner min-width"
    # max-width: 100% resolves to a px value; banner must not exceed the viewport.
    assert_operator metrics["bannerRight"] - metrics["bannerLeft"], :<=, metrics["vw"] + 1
    assert_operator metrics["titleFlexGrow"].to_f, :>=, 1.0
    assert_operator metrics["titleFlexShrink"].to_f, :>=, 1.0
    assert_includes [ "0%", "0px" ], metrics["titleFlexBasis"], "#{placement}: title flex-basis 0%"
    assert_equal "0px", metrics["titleMinWidth"]
    assert_equal "hidden", metrics["titleOverflow"]
    assert_equal "ellipsis", metrics["titleTextOverflow"]
    assert_equal "nowrap", metrics["titleWhiteSpace"]
    assert metrics["titleScrollWider"], "#{placement}: long title should overflow and ellipsis"
    assert_in_delta 44.0, metrics["ctaMinHeight"], 1.0, "#{placement}: CTA ≥44px"
    assert_operator metrics["ctaLeft"], :>=, metrics["bannerLeft"] - 1
    assert_operator metrics["ctaRight"], :<=, metrics["bannerRight"] + 1
    assert_operator metrics["ctaRight"], :<=, metrics["vw"] + 1
    assert_operator metrics["ctaLeft"], :>=, -1
  end
end
