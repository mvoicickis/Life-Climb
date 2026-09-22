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

  test "finish card shows when all battles are won and none open" do
    post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream
    assert_response :success

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project.id)
    assert_response :success
    assert_select "#trail-camp-finish-#{@project.id}", text: /All battles won!/
    assert_select "#trail-camp-finish-#{@project.id} .lp-trail-camp-finish__cta"
    assert_select "#trail-camp-finish-#{@project.id} .lp-trail-camp-finish__save-notice"
    assert_select "#trail-camp-finish-#{@project.id} .lp-trail-camp-finish__add"
  end

  test "finish camp turbo stream succeeds and shows undo card" do
    post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream

    post strategy_goal_manual_completion_path(@project), as: :turbo_stream
    assert_response :success
    assert @project.reload.manually_completed?
    assert_match(/Camp finished/, response.body)
    assert_match(/lp-trail-camp-finish__undo/, response.body)
  end

  test "finish card exposes win not saved copy for client rollback" do
    post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream

    get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id, focus_id: @project.id)
    assert_select "#trail-camp-finish-#{@project.id}[data-trail-camp-finish-win-not-saved-value=?]",
                  I18n.t("dash.battlefield.win_not_saved")
  end

  test "undo reopen restores finish prompt via turbo stream" do
    post battle_win_path(@battle), params: { source: "camp_sheet" }, as: :turbo_stream
    post strategy_goal_manual_completion_path(@project), as: :turbo_stream
    assert @project.reload.manually_completed?

    delete strategy_goal_manual_completion_path(@project), as: :turbo_stream
    assert_response :success
    assert_not @project.reload.manually_completed?
    assert_match(/All battles won!/, response.body)
  end
end
