# frozen_string_literal: true

require "test_helper"

class ProjectSectionsMockupTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
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
    @active = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "MVP", position: 0
    )
    @later = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Launch", position: 1
    )
  end

  test "climb path shows every project card and add control" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @active.id)
    assert_response :success

    assert_select ".lp-climb-path__kicker", text: /What gets me there/i
    assert_select "#climb-path-project-#{@active.id} .lp-climb-path__title", text: "MVP"
    assert_select "#climb-path-project-#{@active.id} .lp-climb-path__menu-btn"
    assert_select "#climb-path-project-#{@later.id} .lp-climb-path__title", text: "Launch"
    assert_select "#climb-path-project-#{@later.id} .lp-climb-path__menu-btn"
    assert_select ".lp-climb-path__new-btn", text: /Add a camp/
    assert_select "a.lp-climb-path__link", count: 0
    assert_select ".lp-climb-path__node.is-locked", count: 0
  end

  test "later cards stay equal peers with a menu and no tap link" do
    @later.update!(title: "Today's Page")
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @active.id)
    assert_response :success

    assert_select "#climb-path-project-#{@later.id} .lp-climb-path__title", text: "Today's Page"
    assert_select "#climb-path-project-#{@later.id} .lp-climb-path__title[title=?]", "Today's Page"
    assert_select "#climb-path-project-#{@later.id}.is-menu-enabled .lp-climb-path__menu-btn", minimum: 1
    assert_select ".lp-climb-path__meta.is-locked", count: 0
    assert_select "a.lp-climb-path__link", count: 0
  end

  test "done cards keep the menu" do
    @active.complete!
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @active.id)
    assert_response :success

    assert_select "#climb-path-project-#{@active.id} .lp-climb-path__title", text: /MVP/
    assert_select "#climb-path-project-#{@active.id} .lp-climb-path__menu-btn"
    assert_select "#climb-path-project-#{@later.id} .lp-climb-path__title", text: /Launch/
    assert_select "#climb-path-project-#{@later.id} .lp-climb-path__menu-btn"
  end

  test "empty plan shows an invitation and add control" do
    empty = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Empty path", position: 1
    )
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: empty.id, focus_id: empty.id)
    assert_response :success
    assert_select ".lp-climb-path.is-empty .lp-climb-path__new-btn", text: /Add a camp/
    assert_select "#climb-path-empty", text: /Add a camp to this path/
    assert_select ".lp-climb-path__project", count: 0
  end

  test "rename succeeds on a later section" do
    patch strategy_goal_path(@later), params: { title: "Today's Page" }
    assert_response :redirect
    assert_equal "Today's Page", @later.reload.title
    assert_not @later.completed?

    follow_redirect!
    assert_response :success
    assert_select "#climb-path-project-#{@later.id} .lp-climb-path__title", text: "Today's Page"
    assert_select "#climb-path-project-#{@active.id} .lp-climb-path__title", text: /MVP/
  end

  test "delete succeeds on a later section" do
    assert_difference -> { @plan.children.where(horizon: "project").count }, -1 do
      delete strategy_goal_path(@later)
    end
    assert_response :redirect
    assert_not StrategyGoal.exists?(@later.id)

    follow_redirect!
    assert_response :success
    assert_select ".lp-climb-path__node", text: /Launch/, count: 0
    assert_select "#climb-path-project-#{@active.id} .lp-climb-path__title", text: /MVP/
  end

  test "mid-list delete keeps remaining positions" do
    section_c = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Polish", position: 2
    )
    position_a = @active.position
    position_b = @later.position
    position_c = section_c.position

    delete strategy_goal_path(@later)
    assert_response :redirect
    assert_not StrategyGoal.exists?(@later.id)

    assert_equal position_a, @active.reload.position
    assert_equal position_c, section_c.reload.position
    assert_not_equal position_b, section_c.position

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @active.id)
    assert_response :success
    assert_select "#climb-path-project-#{@active.id} .lp-climb-path__title", text: /MVP/
    assert_select "#climb-path-project-#{section_c.id} .lp-climb-path__title", text: /Polish/
    assert_select ".lp-climb-path__node", text: /Launch/, count: 0
    assert_select ".lp-climb-path__node.is-locked", count: 0
  end
end
