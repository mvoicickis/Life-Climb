# frozen_string_literal: true

require "application_system_test_case"

class ProjectSectionsNextArrowTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    page.driver.browser.manage.window.resize_to(390, 844)

    Onboarding::Run.call(
      user: @user, area_key: "career", title: "Ship LifePoints",
      ideal_scene: "App live", current_reality: "Building", next_win: "Launch",
      today_mission: "Write tests", closer_percent: 20, route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
    @camps = 9.times.map do |i|
      camp = @plan.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "project", title: "Camp #{i + 1}", position: i
      )
      leaf = practice_leaf_for!(camp)
      leaf.children.create!(
        user: @user, life_area: @area, life_journey: @journey,
        horizon: "day", title: "Step #{i + 1}", scheduled_on: Date.current, position: 0
      )
      camp
    end
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
  end

  test "forward arrow advances snap-aligned through all section cards" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camps.first.id)
    assert_selector ".lp-rpg-sections__track", wait: 5
    assert_selector ".lp-rpg-sections__item", minimum: 9

    positions = page.evaluate_script(<<~JS)
      (function() {
        var el = document.querySelector('.lp-rpg-sections[data-controller~="strategy-plan-rail"]');
        var ctrl = window.Stimulus.getControllerForElementAndIdentifier(el, 'strategy-plan-rail');
        var track = ctrl.trackTarget;
        track.scrollLeft = 0;
        track.dispatchEvent(new Event('scroll'));
        var positions = [track.scrollLeft];
        for (var i = 0; i < 14; i++) {
          var before = track.scrollLeft;
          ctrl.scrollToNextCard();
          positions.push(track.scrollLeft);
          if (track.scrollLeft <= before + 1) break;
        }
        return positions;
      })()
    JS

    advancing = positions.each_cons(2).count { |a, b| b.to_f > a.to_f + 1 }
    assert advancing >= 5, "expected multiple forward advances, got positions=#{positions.inspect}"

    at_end = page.evaluate_script(<<~JS)
      (function() {
        var track = document.querySelector('.lp-rpg-sections__track');
        var max = track.scrollWidth - track.clientWidth;
        return track.scrollLeft >= max - 2;
      })()
    JS
    assert at_end, "should reach end of track after repeated › advances (positions=#{positions.inspect})"

    before = page.evaluate_script("document.querySelector('.lp-rpg-sections__track').scrollLeft").to_f
    page.evaluate_script(<<~JS)
      (function() {
        var track = document.querySelector('.lp-rpg-sections__track');
        track.scrollBy(-120, 0);
        return track.scrollLeft;
      })()
    JS
    after = page.evaluate_script("document.querySelector('.lp-rpg-sections__track').scrollLeft").to_f
    assert after < before - 1, "native track scroll should still move backward (#{before} -> #{after})"
  end

  test "forward arrow button click advances the track" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 5

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @camps.first.id)
    assert_selector ".lp-rpg-sections__track", wait: 5

    page.evaluate_script(<<~JS)
      (function() {
        var track = document.querySelector('.lp-rpg-sections__track');
        track.scrollLeft = 0;
        track.dispatchEvent(new Event('scroll'));
        return true;
      })()
    JS
    assert_selector "button.lp-rpg-sections__arrow.is-next:not([hidden])", wait: 5

    before = page.evaluate_script("document.querySelector('.lp-rpg-sections__track').scrollLeft").to_f
    page.evaluate_script(<<~JS)
      (function() {
        var btn = document.querySelector('button.lp-rpg-sections__arrow.is-next');
        btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
        return true;
      })()
    JS
    after = page.evaluate_script("document.querySelector('.lp-rpg-sections__track').scrollLeft").to_f
    assert after > before + 1, "› click should advance scroll (#{before} -> #{after})"
  end
end
