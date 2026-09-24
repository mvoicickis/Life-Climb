# frozen_string_literal: true

require "test_helper"

class TrailCampSettledSheetTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    allow_extra_climbs!(@user)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Live",
      current_reality: "Building",
      today_mission: "Write tests",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      horizon: "goal", title: "Trail summit"
    }
    @goal = @user.strategy_goals.for_kind("goal").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @goal.id, horizon: "plan", title: "Main path"
    }
    @plan = @user.strategy_goals.for_kind("plan").last
    post strategy_goals_path, params: {
      life_area_id: @area.id, life_journey_id: @journey.id,
      parent_id: @plan.id, horizon: "project", title: "Finished camp",
      color_key: "teal", trail_x: 0.48, trail_y: 0.72
    }
    @project = @user.strategy_goals.for_kind("project").last
  end

  def complete_camp!(project)
    battle = project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Daily habit", scheduled_on: Date.current, position: 0,
      repeat: "daily"
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
    Battles::CompleteTodo.call(todo: todo, user: @user, session: {})
    project.manually_complete!
    project.reload
  end

  test "completed camp sheet shows settled card without idle or add pill" do
    complete_camp!(@project)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success

    assert_select "#trail-camp-finish-#{@project.id}[data-trail-camp-finish-finished-settled-value='true']"
    assert_select "#trail-camp-finish-#{@project.id} [data-trail-camp-finish-target='settledCard']"
    assert_match I18n.t("strategy.rpg.trail.finish_camp_card.finished"), response.body
    assert_select "#trail-camp-finish-#{@project.id} button.lp-trail-camp-finish__undo",
                  text: I18n.t("strategy.rpg.trail.finish_camp_card.reopen_camp")
    assert_select "#trail-camp-finish-#{@project.id} form.lp-trail-camp-finish__reopen-form[data-turbo='true']"
    assert_select "#trail-camp-finish-#{@project.id} [data-trail-camp-finish-target='undoCard']", count: 0
    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__scroll.is-idle", count: 0
    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__composer-trigger", count: 0
    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__scroll.is-camp-completed"
  end

  test "reopen turbo stream restores battles and clears settled card" do
    complete_camp!(@project)

    delete strategy_goal_manual_completion_path(@project), as: :turbo_stream
    assert_response :success

    assert_match %(action="replace" target="trail-battles-#{@project.id}"), response.body
    assert_match %(action="replace" target="trail-camp-finish-#{@project.id}"), response.body
    refute @project.reload.manually_completed?
    refute @project.completed?
    assert_match I18n.t("strategy.rpg.trail.camp_idle.won_pill"), response.body
    refute_match I18n.t("strategy.rpg.trail.finish_camp_card.finished"), response.body
  end

  test "open camp unchanged when not completed" do
    @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Open fight", scheduled_on: Date.current, position: 0
    )

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success

    assert_select "#trail-camp-finish-#{@project.id}[data-trail-camp-finish-finished-settled-value='false']"
    assert_select "#trail-camp-finish-#{@project.id} [data-trail-camp-finish-target='settledCard']", count: 0
    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__composer-trigger"
  end
end
