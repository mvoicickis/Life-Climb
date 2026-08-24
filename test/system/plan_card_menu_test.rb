# frozen_string_literal: true

require "application_system_test_case"

# V4 dropped the plan rail overflow menu. Multi-plan focus uses HUD links;
# destination rename lives on the peak flag → #destination-edit-GOALID.
class PlanCardMenuTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    allow_extra_climbs!(@user)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ], character: "fox", mountain_trail_tour_ack: 7)
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan_a = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Alpha Path", position: 0
    )
    @plan_b = @goal.children.create!(
      user: @user, life_area: @journey.life_area, life_journey: @journey,
      horizon: "plan", title: "Beta Path", position: 1
    )
    [ @plan_a, @plan_b ].each_with_index do |plan, idx|
      project = plan.children.create!(
        user: @user, life_area: @journey.life_area, life_journey: @journey,
        horizon: "project", title: "Camp #{idx}", position: 0
      )
      project_leaf = practice_leaf_for!(project)
      project_leaf.children.create!(
        user: @user, life_area: @journey.life_area, life_journey: @journey,
        horizon: "day", title: "Fight #{idx}", scheduled_on: Date.current, position: 0
      )
    end
  end

  test "HUD plan links switch focus between plans" do
    sign_in_and_visit_mountain!
    assert @journey.present?, "expected an onboarded journey"
    assert_no_selector ".lp-rpg-plan-rail"
    assert_no_selector ".lp-rpg-path__menu-btn"

    assert_selector ".lp-trail-hud__plan.is-active", text: /Alpha Path/
    assert_selector ".lp-trail-hud__plan", text: /Beta Path/

    find(".lp-trail-hud__plan", text: /Beta Path/).click
    assert_selector "#strategy-world", wait: 5
    assert_selector ".lp-trail-hud__plan.is-active", text: /Beta Path/, wait: 5
    assert_no_selector ".lp-trail-hud__plan.is-active", text: /Alpha Path/
    assert_includes page.current_url, "plan_id=#{@plan_b.id}"
  end

  test "destination edit dialog is available from the peak flag menu" do
    sign_in_and_visit_mountain!

    assert_selector ".lp-trail__peak-title", text: /Ship LifePoints/i, wait: 5
    assert_selector "dialog#destination-edit-#{@goal.id}", visible: :all

    find(".lp-trail__flag").click
    assert_selector ".lp-trail__peak-menu:not([hidden])", wait: 3
    find(".lp-trail__peak-item", text: /Edit Destination/i).click

    assert_selector "dialog#destination-edit-#{@goal.id}[open]", wait: 3
    within("dialog#destination-edit-#{@goal.id}") do
      assert_field "title", with: "Ship LifePoints"
      fill_in "title", with: "Renamed Destination"
      click_button "Save"
    end

    assert_selector "#strategy-world", wait: 5
    assert_selector ".lp-trail__peak-title", text: /Renamed Destination/i, wait: 5
    assert_equal "Renamed Destination", @goal.reload.title
  end

  test "V4 has no plan card delete menu; HUD plans and destination edit remain" do
    sign_in_and_visit_mountain!
    assert_selector ".lp-trail-hud__plan.is-active", text: /Alpha Path/, wait: 5
    assert_selector ".lp-trail-hud__plan", text: /Beta Path/
    assert_no_selector ".lp-rpg-path__menu"
    assert_no_selector ".lp-rpg-path__menu-item.is-danger"
    assert_selector "dialog#destination-edit-#{@goal.id}", visible: :all
    assert StrategyGoal.exists?(@plan_a.id)
    assert StrategyGoal.exists?(@plan_b.id)
  end

  private

  def sign_in_and_visit_mountain!
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password12345"
    click_button "Sign in"
    assert_selector ".lp-dash-nav", wait: 8
    visit life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan_a.id)
    assert_selector "#strategy-world.lp-rpg.is-v4-phone", wait: 10
    assert_selector "#mountain-trail.lp-trail.is-v4", wait: 10
  end
end
