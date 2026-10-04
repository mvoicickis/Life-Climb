# frozen_string_literal: true

require "application_system_test_case"

class FinishMapReslotTest < ApplicationSystemTestCase
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
      today_mission: "Map reslot",
      closer_percent: 20,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.find_by!(life_journey_id: @journey.id)
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Main path", position: 0
    )
    @camps = 4.times.map do |i|
      @user.strategy_goals.create!(
        life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Camp #{i + 1}",
        color_key: "teal", trail_x: 0.48, trail_y: 0.72, position: i, stage: i
      )
    end
    @camp1, @camp2, @camp3, @camp4 = @camps
    win_all_battles!(@camp1)
    dismiss_onboarding_missions!(@user)
  end

  def win_all_battles!(project)
    project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Win", scheduled_on: Date.current, position: 0
    ).update!(completed_at: Time.current)
  end

  def sign_in_and_visit_mountain!
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_today_v2_shell!
    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_selector "#trail-map-camps", wait: 10
  end

  def builtin_map?
    !ApplicationController.helpers.mountain_trail_custom_photo?(@journey)
  end

  def expected_trail_y_for(camp_id)
    @plan.reload
    trail = Strategy::Trail.for(plan: @plan)
    nodes = trail.visible_nodes
    node = nodes.find { |n| n.id == camp_id }
    helper = Object.new.extend(MountainTrailHelper)
    layout = helper.mountain_trail_map_layout_slot(node, nodes, builtin_map: builtin_map?)
    layout[:y]
  end

  def camp_trail_y(camp_id)
    camp = find("#trail-camp-#{camp_id}", visible: :all)
    style = camp[:style] || camp["style"]
    match = style.to_s.match(/--lp-trail-y:\s*([^;]+)/)
    match ? match[1].strip.to_f : nil
  end

  def map_camp_ids
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("#trail-map-camps .lp-trail-camp")).map((el) => el.id.replace("trail-camp-", ""))
    JS
  end

  def install_stream_action_logger!
    page.execute_script(<<~JS)
      window.__streamActions = [];
      document.addEventListener("turbo:before-stream-render", (event) => {
        const stream = event.detail?.newStream;
        if (!stream) return;
        window.__streamActions.push({
          action: stream.getAttribute("action"),
          target: stream.getAttribute("target")
        });
      }, { capture: true });
    JS
  end

  def logged_stream_actions
    page.evaluate_script("window.__streamActions || []")
  end

  test "finish camp reslots map tents without reload at 360px" do
    page.driver.browser.manage.window.resize_to(360, 700)
    sign_in_and_visit_mountain!

    assert_equal 1, page.evaluate_script('document.querySelectorAll("#trail-map-camps").length')

    install_stream_action_logger!
    find("#trail-camp-#{@camp1.id}", visible: :all).click
    assert_selector ".lp-trail-sheet.is-open", wait: 5
    assert_selector "#trail-camp-finish-#{@camp1.id} [data-trail-camp-finish-target='promptCard']", wait: 5

    click_button I18n.t("strategy.rpg.trail.finish_camp_card.finish")

    assert_selector "#trail-camp-finish-#{@camp1.id} [data-trail-camp-finish-target='undoCard']", wait: 10

    streams = logged_stream_actions
    assert streams.any? { |s| s["action"] == "replace" && s["target"] == "trail-map-camps" },
           "expected turbo replace trail-map-camps in stream log, got: #{streams.inspect}"

    assert_no_selector "#trail-map-camps #trail-camp-#{@camp1.id}"
    assert_selector "#trail-map-camps #trail-camp-#{@camp2.id}"
    assert_selector "#trail-map-camps #trail-camp-#{@camp3.id}"
    assert_selector "#trail-map-camps #trail-camp-#{@camp4.id}"

    expected_bottom_y = expected_trail_y_for(@camp2.id)
    assert_in_delta expected_bottom_y, camp_trail_y(@camp2.id), 0.0001,
                    "camp 2 should sit in bottom slot after finish (expected y=#{expected_bottom_y})"

    assert_in_delta expected_trail_y_for(@camp3.id), camp_trail_y(@camp3.id), 0.0001
    assert_in_delta expected_trail_y_for(@camp4.id), camp_trail_y(@camp4.id), 0.0001

    assert_selector ".lp-trail-map-sign__pill--finished", text: /1 camp finished/i
  end

  test "undo finish puts camp 1 back in bottom slot and shifts camp 2 up" do
    page.driver.browser.manage.window.resize_to(360, 700)
    sign_in_and_visit_mountain!

    find("#trail-camp-#{@camp1.id}", visible: :all).click
    assert_selector ".lp-trail-sheet.is-open", wait: 5
    click_button I18n.t("strategy.rpg.trail.finish_camp_card.finish")
    assert_selector "#trail-camp-finish-#{@camp1.id} [data-trail-camp-finish-target='undoCard']", wait: 10

    click_button I18n.t("strategy.rpg.trail.undo")
    assert_selector "#trail-camp-finish-#{@camp1.id} [data-trail-camp-finish-target='promptCard']", wait: 10

    assert_selector "#trail-map-camps #trail-camp-#{@camp1.id}"
    assert_in_delta expected_trail_y_for(@camp1.id), camp_trail_y(@camp1.id), 0.0001
    assert_in_delta expected_trail_y_for(@camp2.id), camp_trail_y(@camp2.id), 0.0001
    refute @camp1.reload.manually_completed?
  end
end
