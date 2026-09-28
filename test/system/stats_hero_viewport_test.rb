# frozen_string_literal: true

require "application_system_test_case"

class StatsHeroViewportTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    seed_climb!(@user, today_mission: "Stats hero viewport")
    dismiss_onboarding_missions!(@user)
    journey = @user.primary_focused_journey
    plan = @user.strategy_goals.for_kind("goal").roots.first.children.find(&:plan?)
    project = plan.children.create!(
      user: @user,
      life_area: journey.life_area,
      life_journey: journey,
      horizon: "project",
      title: "Wake up early before the house is loud and honking starts",
      position: 99
    )
    battle = project.children.create!(
      user: @user,
      life_area: journey.life_area,
      life_journey: journey,
      horizon: "day",
      title: "Long camp win",
      scheduled_on: Date.current,
      position: 0
    )
    battle.update!(completed_at: Time.current)
  end

  test "stats page fits at 360 without horizontal overflow" do
    page.driver.browser.manage.window.resize_to(360, 700)
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!

    visit life_points_path
    assert_selector ".lp-stats-hero", wait: 5
    assert_selector ".lp-stats-row__name", wait: 5

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector('.lp-stats-hero__link');
        const name = document.querySelector('.lp-stats-row__name');
        const linkRange = document.createRange();
        linkRange.selectNodeContents(link);
        const linkTextRect = linkRange.getBoundingClientRect();
        const nameRange = document.createRange();
        nameRange.selectNodeContents(name);
        const nameTextRect = nameRange.getBoundingClientRect();
        return {
          vw: window.innerWidth,
          scrollWidth: document.documentElement.scrollWidth,
          linkTextRight: linkTextRect.right,
          nameTextRight: nameTextRect.right
        };
      })()
    JS

    assert_operator metrics["scrollWidth"], :<=, metrics["vw"] + 1,
                    "page should not scroll horizontally at 360px"
    assert_operator metrics["linkTextRight"], :<=, metrics["vw"] + 1,
                    "Open Mountain link should not overflow viewport"
    assert_operator metrics["nameTextRight"], :<=, metrics["vw"] + 1,
                    "Long camp name should not overflow viewport"
  end
end
