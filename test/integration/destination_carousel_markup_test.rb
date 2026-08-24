# frozen_string_literal: true

require "test_helper"

class DestinationCarouselMarkupTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
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
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Career Path", position: 0
    )
  end

  test "mountain renders one static destination with rename and no switching UI" do
    get life_journey_path(@journey, goal_id: @goal.id)
    assert_response :success

    assert_select ".lp-rpg.is-v4-phone"
    assert_select ".lp-trail__peak-title", text: /Ship LifePoints/i
    assert_select ".lp-trail__peak-item", text: /Edit Destination/i
    assert_select "dialog#destination-edit-#{@goal.id}"
    assert_select ".lp-trail-hud"

    # No switching or extra-create affordances remain.
    assert_select ".lp-rpg-destination-carousel", count: 0
    assert_select ".lp-rpg-destination-carousel__arrow", count: 0
    assert_select ".lp-rpg-destination-carousel__peek", count: 0
    assert_select ".lp-rpg-destination-dots", count: 0
    assert_select ".lp-rpg-destination-swipe-hint", count: 0
    assert_select ".lp-rpg-destination-add", count: 0
    assert_select ".lp-rpg-destination-menu__item[data-action*='destination-switcher#openCreate']", count: 0
  end

  test "renaming the destination from mountain returns with the new title" do
    patch strategy_goal_path(@goal), params: { title: "Debt Free" }
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id)
    assert_equal "Debt Free", @goal.reload.title

    follow_redirect!
    assert_response :success
    assert_select ".lp-trail__peak-title", text: /Debt Free/i
  end
end
