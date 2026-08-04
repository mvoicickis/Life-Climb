# frozen_string_literal: true

require "test_helper"

class FirstClimbTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Become a licensed plumber",
      ideal_scene: "Own my van and clients",
      current_reality: "Working a day job",
      next_win: "Pass first exam section",
      today_mission: "Study",
      closer_percent: 5,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
  end

  test "new climber sees first-climb coach instead of crowded mountain chrome" do
    get life_journey_path(@journey)
    assert_response :success
    assert_select "#first-climb-coach"
    assert_select ".lp-first-climb__cta[value=?]", "Start my climb"
    assert_select "#strategy-camp-notebook", count: 0
    assert_select ".lp-world-hud__chip.is-sp", count: 0
  end

  test "first climb scaffolds plan project battle and opens today fight" do
    assert_difference -> { @user.strategy_goals.for_kind("day").count }, +1 do
      post first_climbs_path, params: {
        life_journey_id: @journey.id,
        plan_title: "Get certified",
        today_action: "Study chapter 1 for 20 minutes"
      }
    end

    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_select ".lp-dash-human-win__body", text: /Study chapter 1/i
    assert_select ".lp-dash-route.is-first-climb", count: 0
    assert @user.daily_todos.for_day(Date.current).exists?(title: "Study chapter 1 for 20 minutes")
    assert Strategy::HierarchyReady.call(user: @user, journey: @journey)

    # One real action only — scaffolding "Plan Your Route" mission is retired.
    assert_select ".lp-dash-section.is-battles .lp-dash-battle__list > .lp-dash-battle__item", count: 1
    assert_select ".lp-dash-section.is-battles .lp-dash-battle__name", text: "Study chapter 1 for 20 minutes"
    assert_no_match(/Plan Your Route/i, response.body)

    # Character-first climb band (not the old mountain hero).
    assert_select ".lp-dash-climb", count: 1
    assert_select ".lp-dash-climb__climber[data-battle-day-target='campArt']", count: 1
    assert_select ".lp-dash-hero", count: 0
  end

  test "today dead-end shows first-climb coach when spine empty" do
    get dashboard_path
    assert_response :success
    assert_select "#first-climb-coach"
    assert_select ".lp-first-climb__title", text: /today count/i
  end

  test "double submit creates only one plan project battle tree" do
    params = {
      life_journey_id: @journey.id,
      plan_title: "Get certified",
      today_action: "Study chapter 1 for 20 minutes"
    }

    assert_difference -> { @user.strategy_goals.for_kind("plan").count }, +1 do
      assert_difference -> { @user.strategy_goals.for_kind("day").count }, +1 do
        post first_climbs_path, params: params
        assert_redirected_to dashboard_path

        # Second tap / retry with different titles must not spawn another spine.
        post first_climbs_path, params: params.merge(
          plan_title: "Get certified AGAIN",
          today_action: "A second accidental battle"
        )
        assert_redirected_to dashboard_path
      end
    end

    @goal.reload
    plans = @goal.children.select(&:plan?)
    assert_equal 1, plans.size, "expected one plan, got: #{plans.map(&:title).inspect}"
    assert_equal "Get certified", plans.first.title

    projects = plans.first.children.select(&:project?)
    assert_equal 1, projects.size

    nested = projects.first.children.select(&:project?)
    assert_equal 1, nested.size
    assert_equal I18n.t("strategy.first_climb.nested_camp_title"), nested.first.title

    battles = nested.first.children.select(&:day?)
    assert_equal 1, battles.size
    assert_equal "Study chapter 1 for 20 minutes", battles.first.title
    assert_equal 1, @user.daily_todos.for_day(Date.current).where(title: "Study chapter 1 for 20 minutes").count
    assert_equal 0, @user.daily_todos.for_day(Date.current).where(title: "A second accidental battle").count
  end

  test "first climb form disables submit on click via stimulus hook" do
    get dashboard_path
    assert_response :success
    assert_select "form.lp-first-climb__form[data-controller='first-climb']"
    assert_select "form.lp-first-climb__form[data-action*='submit->first-climb#disable']"
    assert_select ".lp-first-climb__cta[data-first-climb-target='submit']"
  end
end
