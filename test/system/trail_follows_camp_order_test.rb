# frozen_string_literal: true

require "application_system_test_case"

class TrailFollowsCampOrderTest < ApplicationSystemTestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      today_mission: "Trail order",
      closer_percent: 20,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.find_by!(life_journey_id: @journey.id)
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Main path", position: 0
    )
    titles = %w[A B C D E]
    @camps = titles.map.with_index do |title, index|
      @user.strategy_goals.create!(
        life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: title,
        position: index, stage: index
      )
    end
    Strategy::ArrangeCamps.call(
      user: @user,
      plan: @plan,
      groups: [
        { camp_ids: [ @camps[0].id, @camps[1].id ] },
        { camp_ids: [ @camps[2].id, @camps[3].id, @camps[4].id ] }
      ]
    )
    @camp_a, @camp_b, @camp_c, @camp_d, @camp_e = @camps
    win_all_battles!(@camp_a)
    dismiss_onboarding_missions!(@user)
  end

  def win_all_battles!(project)
    project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Win", scheduled_on: Date.current, position: 0
    ).update!(completed_at: Time.current)
  end

  def camp_trail_y(camp_id)
    camp = find("#trail-camp-#{camp_id}", visible: :all)
    style = camp[:style] || camp["style"]
    match = style.to_s.match(/--lp-trail-y:\s*([^;]+)/)
    match ? match[1].strip.to_f : nil
  end

  def bottom_slot_camp_id
    page.evaluate_script(<<~JS)
      (() => {
        const camps = Array.from(document.querySelectorAll("#trail-map-camps .lp-trail-camp"));
        if (!camps.length) return null;
        let bottom = camps[0];
        let bottomY = parseFloat(getComputedStyle(bottom).getPropertyValue("--lp-trail-y")) || 0;
        camps.forEach((el) => {
          const y = parseFloat(getComputedStyle(el).getPropertyValue("--lp-trail-y")) || 0;
          if (y > bottomY) { bottom = el; bottomY = y; }
        });
        return bottom.id.replace("trail-camp-", "");
      })()
    JS
  end

  test "two step arrange finish pulls next camp onto map at 360px" do
    page.driver.browser.manage.window.resize_to(360, 700)

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!

    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_selector "#trail-map-camps #trail-camp-#{@camp_a.id}", wait: 10

    find("#trail-camp-#{@camp_a.id}", visible: :all).click
    assert_selector ".lp-trail-sheet.is-open", wait: 5
    click_button I18n.t("strategy.rpg.trail.finish_camp_card.finish")
    assert_selector "#trail-camp-finish-#{@camp_a.id} [data-trail-camp-finish-target='undoCard']", wait: 10

    assert_no_selector "#trail-map-camps #trail-camp-#{@camp_a.id}"
    assert_selector "#trail-map-camps #trail-camp-#{@camp_b.id}"
    assert_selector "#trail-map-camps #trail-camp-#{@camp_c.id}"
    assert_selector "#trail-map-camps #trail-camp-#{@camp_d.id}"
    assert_no_selector "#trail-map-camps #trail-camp-#{@camp_e.id}"

    assert_equal @camp_b.id.to_s, bottom_slot_camp_id
    trail = Strategy::Trail.for(plan: @plan.reload)
    assert_equal @camp_d.id, trail.visible_nodes.last.id
  end
end
