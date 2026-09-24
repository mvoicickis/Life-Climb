# frozen_string_literal: true

require "test_helper"

class TrailCampFinishCardTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox")
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_area(@area.id).for_kind("goal").roots.first
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Path", position: 0
    )
    @project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Camp A", position: 0
    )
    @battle = @project.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey,
      horizon: "day",
      title: "Win me",
      scheduled_on: Date.current,
      position: 0
    )
  end

  test "turbo win shows finish card when last battle is won" do
    post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream
    assert_response :success

    assert_match(/trail-camp-finish-#{@project.id}/, @response.body)
    assert_match(/All battles won!/, @response.body)
    assert_match(/Add another battle/, @response.body)
    assert_match(/Finish camp/, @response.body)
  end

  test "finish card shows for one-shot won yesterday without idle keep copy" do
    @battle.update!(completed_at: 1.day.ago.noon)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project.id)
    assert_response :success
    assert_select "#trail-camp-finish-#{@project.id} .lp-trail-camp-finish__title",
                  text: I18n.t("strategy.rpg.trail.finish_camp_card.title")
    assert_select ".lp-trail-camp-idle__title", text: I18n.t("strategy.rpg.trail.camp_idle.keep_title"), count: 0
  end

  test "daily battle won today does not show finish card" do
    @battle.update!(repeat: "daily")
    Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: Date.current, to: Date.current)
    todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: @battle.id)
    Battles::CompleteTodo.call(todo: todo, user: @user, session: {})

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project.id)
    assert_response :success
    assert_select "#trail-camp-finish-#{@project.id} .lp-trail-camp-finish__card", count: 0
  end

  test "open battle does not show finish card" do
    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project.id)
    assert_response :success
    assert_select "#trail-camp-finish-#{@project.id} .lp-trail-camp-finish__card", count: 0
  end

  test "completed camp shows settled card not finish prompt" do
    @battle.complete!
    @project.update!(completed_at: Time.current, manually_completed_at: Time.current)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project.id)
    assert_response :success
    assert_select "#trail-camp-finish-#{@project.id} [data-trail-camp-finish-target='settledCard']"
    assert_select "#trail-camp-finish-#{@project.id} [data-trail-camp-finish-target='promptCard']", count: 0
  end

  test "two camps only shows finish card for open qualifying camp" do
    @battle.complete!
    project_b = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project", title: "Camp B", position: 1, stage: 1
    )
    project_b.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey,
      horizon: "day",
      title: "Still fighting",
      scheduled_on: Date.current,
      position: 0
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: project_b.id)
    assert_response :success
    assert_select "#trail-camp-finish-#{project_b.id} .lp-trail-camp-finish__card", count: 0
    assert_select "#trail-camp-finish-#{@project.id}[data-camp-overlay-panel='#{@project.id}'] .lp-trail-camp-finish__card",
                  count: 1
  end
end
