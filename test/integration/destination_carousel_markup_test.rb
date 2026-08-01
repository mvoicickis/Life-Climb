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
    @other = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey,
      horizon: "goal", title: "Health Summit", position: 1
    )
    @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Career Path", position: 0
    )
    @other.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Run Path", position: 0
    )
  end

  test "mountain renders one-active destination carousel with arrows and peeks" do
    get life_journey_path(@journey, goal_id: @goal.id)
    assert_response :success

    assert_select ".lp-rpg-destination-carousel.is-multi"
    assert_select ".lp-rpg-destination-carousel__title", text: /Ship LifePoints/i
    assert_select ".lp-rpg-destination-carousel__active[data-controller~='plan-card-menu']"
    assert_select ".lp-rpg-destination-menu__btn[data-action*='plan-card-menu#toggle']"
    assert_select ".lp-rpg-destination-menu__item[data-action*='plan-card-menu#edit']", text: /Edit Destination/i
    assert_select ".lp-rpg-destination-menu__item[data-action*='destination-switcher#openCreate']", text: /New Destination/i
    assert_select "dialog#destination-edit-#{@goal.id}"
    assert_select "dialog#destination-create"
    assert_select ".lp-rpg-summit__pct", count: 0
    assert_select ".lp-rpg-destination__new", count: 0
    assert_select "a.lp-rpg-destination-carousel__arrow.is-next[href=?]",
                  life_journey_path(@journey, goal_id: @other.id)
    assert_select ".lp-rpg-destination-carousel__peek.is-next", text: /Health Summit/i
    assert_select ".lp-rpg-destination-dots__dot", count: 2
    assert_select ".lp-rpg-path", text: /Career Path/
    assert_select ".lp-rpg-path.is-focus .lp-rpg-path__pct[data-strategy-celebrate-target='progressBar']"
    assert_select ".lp-rpg-path-focus", count: 1
    assert_select ".lp-rpg-goals", count: 0
  end

  test "switching destination focus via goal_id updates mission rail" do
    get life_journey_path(@journey, goal_id: @other.id)
    assert_response :success

    assert_select ".lp-rpg-destination-carousel__title", text: /Health Summit/i
    assert_select "dialog#destination-edit-#{@other.id}"
    assert_select ".lp-rpg-path", text: /Run Path/
    assert_select ".lp-rpg-path", text: /Career Path/, count: 0
  end

  test "renaming a destination from mountain returns with the new title" do
    patch strategy_goal_path(@goal), params: { title: "Debt Free" }
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id)
    assert_equal "Debt Free", @goal.reload.title

    follow_redirect!
    assert_response :success
    assert_select ".lp-rpg-destination-carousel__title", text: /Debt Free/i
    assert_select ".lp-rpg-destination-dots__dot", count: 2
  end
end
