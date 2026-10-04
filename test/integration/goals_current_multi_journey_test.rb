# frozen_string_literal: true

require "test_helper"

class GoalsCurrentMultiJourneyTest < ActionDispatch::IntegrationTest
  setup do
    Goals::Current.clear_cache!
    @user = users(:two)
    @user.update!(character: "fox", planning_version: 2, onboarding_completed_at: Time.current)
    sign_in_as @user

    @bootstrap = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Goal A",
      camp_titles: [ "Camp one", "Camp two" ]
    )
    @journey_a = @bootstrap.journey
    @goal_a = @bootstrap.goal
    @area = @journey_a.life_area

    finish_first_camp!(@bootstrap)
    win_battle_yesterday!(@bootstrap.first_battle) if @bootstrap.first_battle

    @stale_battle = @bootstrap.projects.first.children.create!(
      user: @user,
      life_area: @area,
      life_journey: @journey_a,
      horizon: "day",
      title: "Stale on completed journey",
      scheduled_on: Date.current,
      position: 1,
      repeat: "none"
    )

    @journey_b, @goal_b = build_journey_b!
    Focus::SetJourneys.call(user: @user, journey_ids: [ @journey_b.id ])
    Journeys::Complete.call(user: @user, journey: @journey_a)
    @user.reload
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
  end

  teardown do
    Goals::Current.clear_cache!
  end

  test "surfaces show goal B never A across Today push Mountain Stats EOD and DueDayBattles" do
    pair = Goals::Current.call(user: @user)
    assert_equal @goal_b.id, pair.goal.id
    assert_not_equal @goal_a.id, pair.goal.id

    get dashboard_path
    assert_response :success
    assert_includes response.body, @goal_b.title
    assert_not_includes response.body, @goal_a.title

    copy = Notifications::MorningNudgeCopy.for(user: @user, date: Date.current)
    assert_includes copy.title, @goal_b.title
    assert_not_includes copy.title, @goal_a.title

    get life_journey_path(@journey_b)
    assert_response :success
    assert_includes response.body, @goal_b.title

    get life_points_path
    assert_response :success
    assert_select "a.lp-stats-hero__link[href=?]", life_journey_path(@journey_b)

    open_camps = Today::EndOfDay.open_camps(strategy_goal: pair.goal)
    assert open_camps.any?
    assert_equal @goal_b.id, pair.goal.id

    due_ids = Strategy::DueDayBattles.on(user: @user, life_area: @area, on: Date.current).map(&:id)
    assert_includes due_ids, @daily_b.id
    assert_not_includes due_ids, @stale_battle.id
  end

  test "draft journey battles still surface on Today" do
    draft = @user.life_journeys.create!(
      life_area: @area,
      title: "Draft climb",
      ideal_scene: "Ideal",
      current_reality: "Now",
      status: "draft",
      gap_percent: 50
    )
    draft_goal = @user.strategy_goals.create!(
      life_area: @area,
      life_journey: draft,
      horizon: "goal",
      title: "Draft goal",
      position: 2,
      due_on: Strategy::YearCycle.default_goal_due
    )
    plan = draft_goal.children.create!(
      user: @user, life_area: @area, life_journey: draft,
      horizon: "plan", title: "Plan", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: @area, life_journey: draft,
      horizon: "project", title: "Draft camp", position: 0, stage: 0
    )
    draft_battle = project.children.create!(
      user: @user, life_area: @area, life_journey: draft,
      horizon: "day", title: "Draft daily", scheduled_on: Date.current,
      position: 0, repeat: "daily"
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    due_ids = Strategy::DueDayBattles.on(user: @user, life_area: @area, on: Date.current).map(&:id)
    assert_includes due_ids, draft_battle.id
  end

  private

  def finish_first_camp!(bootstrap)
    camp = bootstrap.projects.first
    camp.complete!
    Strategy::SyncCompletion.call(project: camp)
  end

  def win_battle_yesterday!(battle)
    yesterday = Date.current - 1.day
    travel_to Time.zone.local(yesterday.year, yesterday.month, yesterday.day, 10, 0, 0) do
      battle.update!(scheduled_on: yesterday)
      Strategy::CascadeToDaily.call(user: @user, life_area: @area, from: yesterday, to: yesterday)
      todo = @user.daily_todos.for_day(yesterday).find_by!(strategy_goal_id: battle.id)
      todo.update!(completed_at: Time.current)
    end
  end

  def build_journey_b!
    journey = Journeys::Create.call(
      user: @user,
      life_area: @area,
      title: "Goal B",
      ideal_scene: "Ideal B",
      current_reality: "Now B",
      closer_percent: 12
    )
    goal = @user.strategy_goals.create!(
      life_area: @area,
      life_journey: journey,
      horizon: "goal",
      title: "Goal B",
      position: 1,
      due_on: Strategy::YearCycle.default_goal_due
    )
    plan = goal.children.create!(
      user: @user, life_area: @area, life_journey: journey,
      horizon: "plan", title: "Main path", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: @area, life_journey: journey,
      horizon: "project", title: "B camp", position: 0, stage: 0
    )
    @daily_b = project.children.create!(
      user: @user, life_area: @area, life_journey: journey,
      horizon: "day", title: "B daily", scheduled_on: Date.current,
      position: 0, repeat: "daily"
    )
    [ journey, goal ]
  end
end
