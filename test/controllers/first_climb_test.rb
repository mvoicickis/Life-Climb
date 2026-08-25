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

  test "new climber sees destination overlay on mountain trail" do
    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-trail-destination__title", text: /Where do you want to be/i
    assert_select ".lp-trail-destination__cta[value=?]", "Plant my flag →"
    assert_select "#mountain-trail"
    assert_select "#first-climb-coach", count: 0
  end

  test "plant destination scaffolds plan and opens trail" do
    assert_difference -> { @user.strategy_goals.for_kind("plan").count }, +1 do
      post life_journey_plant_destinations_path, params: {
        life_journey_id: @journey.id,
        goal_id: @goal.id,
        title: "Run a 10k"
      }
    end

    plan = @goal.reload.children.for_kind("plan").not_holding.first
    assert_redirected_to life_journey_path(@journey, goal_id: @goal.id, plan_id: plan.id)
    follow_redirect!
    assert_select "#mountain-trail"
    assert_select ".lp-trail-destination", count: 0
    assert_equal 0, plan.children.for_kind("project").count
  end

  test "first climb scaffolds plan project battle and opens today fight" do
    assert_difference -> { @user.strategy_goals.for_kind("day").count }, +1 do
      post first_climbs_path, params: {
        life_journey_id: @journey.id,
        goal_id: @goal.id,
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
    assert_battle_row!(title: "Study chapter 1 for 20 minutes", camp: "Get certified")
    assert_select ".lp-dash-timeline .lp-dash-tcard", count: 0
    assert_no_match(/Plan Your Route/i, response.body)

    assert_today_v2_shell!
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
      goal_id: @goal.id,
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

    battles = projects.first.children.select(&:day?)
    assert_equal 1, battles.size
    assert_equal "Study chapter 1 for 20 minutes", battles.first.title
    assert_equal projects.first.id, battles.first.parent_id
    assert_equal 1, @user.daily_todos.for_day(Date.current).where(title: "Study chapter 1 for 20 minutes").count
    assert_equal 0, @user.daily_todos.for_day(Date.current).where(title: "A second accidental battle").count
  end

  test "title param cannot create a second destination (one-goal rule)" do
    Strategy::FirstClimb.call(
      user: @user,
      journey: @journey,
      goal: @goal,
      plan_title: "Get certified",
      today_action: "Study chapter 1 for 20 minutes"
    )

    assert_no_difference -> { @user.strategy_goals.for_kind("goal").roots.count } do
      post first_climbs_path, params: {
        life_journey_id: @journey.id,
        title: "Family Peak",
        plan_title: "Weekend dinners",
        today_action: "Text the family group"
      }
    end

    assert_redirected_to life_journey_path(@journey)
    assert flash[:alert].present?
    assert_nil @user.strategy_goals.for_kind("goal").roots.find_by(title: "Family Peak")
    assert_equal [ "Get certified" ], @goal.reload.children.for_kind("plan").map(&:title)
  end

  test "first climb form disables submit on click via stimulus hook" do
    get dashboard_path
    assert_response :success
    assert_select "form.lp-first-climb__form[data-controller='first-climb']"
    assert_select "form.lp-first-climb__form input[name=goal_id][value=?]", @goal.id.to_s
    assert_select "form.lp-first-climb__form[data-action*='submit->first-climb#disable']"
    assert_select ".lp-first-climb__cta[data-first-climb-target='submit']"
  end

  test "first climb shows category example chips for the area" do
    get dashboard_path
    assert_response :success
    assert_match(/What.?s one big thing you need to finish first/i, response.body)
    assert_match(/What can you do about it today/i, response.body)
    assert_match(/Something that takes weeks, not one day/i, response.body)
    assert_match(/Something small you could finish in the next hour/i, response.body)
    assert_select ".lp-first-climb__chip[data-action='first-climb#fill']", minimum: 4
    assert_select ".lp-first-climb__chip", text: "Get certified"
    assert_select ".lp-first-climb__chip", text: "Land the next role"
    assert_select ".lp-first-climb__chip", text: "Study chapter 1 for 20 minutes"
    assert_select ".lp-first-climb__chip", text: "Update one resume bullet"
    assert_select "#first-climb-plan[data-first-climb-target='planInput']"
    assert_select "#first-climb-action[data-first-climb-target='actionInput']"
  end

  test "onboarding category flag still drives mountain destination overlay" do
    flags = (@journey.setup_flags.presence || {}).stringify_keys.merge(
      Onboarding::Categories::CATEGORY_FLAG => "self"
    )
    @journey.update_columns(setup_flags: flags)

    get life_journey_path(@journey)
    assert_response :success
    assert_select ".lp-trail-destination"
    assert_select ".lp-trail-plant__starter--icon", text: /Get strong/i, count: 0

    post life_journey_plant_destinations_path, params: {
      life_journey_id: @journey.id,
      goal_id: @goal.id,
      title: @goal.title
    }
    plan = @goal.reload.children.for_kind("plan").not_holding.first
    follow_redirect!
    assert_select ".lp-trail-plant__starter--icon", minimum: 1
  end
end
