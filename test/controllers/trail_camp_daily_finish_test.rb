# frozen_string_literal: true

require "test_helper"

class TrailCampDailyFinishTest < ActionDispatch::IntegrationTest
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
      parent_id: @plan.id, horizon: "project", title: "Daily camp",
      color_key: "teal", trail_x: 0.48, trail_y: 0.72
    }
    @project = @user.strategy_goals.for_kind("project").last
  end

  def win_daily_battle_today!
    battle = @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Daily habit", scheduled_on: Date.current, position: 0,
      repeat: "daily"
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day.find_by!(strategy_goal_id: battle.id)
    Battles::CompleteTodo.call(todo: todo, user: @user, session: {})
    battle
  end

  test "won idle one-shot camp with off-day weekly shows finish camp link" do
    off_day = (Date.current.wday + 1) % 7
    @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Off-day weekly", scheduled_on: Date.current,
      repeat: "weekly", repeat_weekdays: [ off_day ], position: 0
    )
    @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "Won today", scheduled_on: Date.current, position: 1
    ).update!(completed_at: Time.current)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success

    assert_select "#trail-battles-#{@project.id} .lp-trail-battles__scroll.is-idle"
    refute_match I18n.t("strategy.rpg.trail.finish_camp_card.title"), response.body
    assert_select "#trail-battles-#{@project.id} button.lp-trail-camp-idle__finish",
                  text: I18n.t("strategy.rpg.trail.finish_camp_card.finish")
  end

  test "won idle daily camp shows finish camp link with turbo form" do
    win_daily_battle_today!

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success

    finish_label = I18n.t("strategy.rpg.trail.finish_camp_card.finish")
    assert_select "#trail-battles-#{@project.id} form.lp-trail-camp-idle__finish-form[data-turbo='true']"
    assert_select "#trail-battles-#{@project.id} button.lp-trail-camp-idle__finish",
                  text: finish_label
    assert_select "form.lp-trail-camp-idle__finish-form[action=?]",
                  strategy_goal_manual_completion_path(@project)
  end

  test "one-shot camp with finish card does not show idle finish link" do
    battle = @project.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "day", title: "One shot", scheduled_on: Date.current, position: 0
    )
    battle.update!(completed_at: Time.current)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success

    assert_match I18n.t("strategy.rpg.trail.finish_camp_card.title"), response.body
    assert_select ".lp-trail-camp-idle__finish", count: 0
  end

  test "completed daily camp does not show idle finish link" do
    win_daily_battle_today!
    @project.update!(completed_at: Time.current, manually_completed_at: Time.current)

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
    assert_response :success

    assert_select ".lp-trail-camp-idle__finish", count: 0
  end

  test "manual completion turbo stream from daily camp fills finish slot with completed card" do
    win_daily_battle_today!

    post strategy_goal_manual_completion_path(@project), as: :turbo_stream
    assert_response :success

    assert_match %(action="replace" target="trail-camp-finish-#{@project.id}"), response.body
    assert_match I18n.t("strategy.rpg.trail.finish_camp_card.finished"), response.body
    assert_match %(data-trail-camp-finish-target="undoCard"), response.body
    assert @project.reload.manually_completed?
  end
end
