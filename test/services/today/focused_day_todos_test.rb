# frozen_string_literal: true

require "test_helper"

class Today::FocusedDayTodosTest < ActiveSupport::TestCase
  include ClimbTestHelper
  include TodayV2TestHelper

  setup do
    @user = users(:one)
    @first = seed_climb!(@user, area_key: "career", title: "First goal", today_mission: "First fight")
    dismiss_onboarding_missions!(@user)
    @second = seed_second_journey!(title: "Second goal", area_key: "career", battle_title: "Second fight")
    Strategy::CascadeToDaily.call(
      user: @user,
      life_area: @first.life_area,
      from: Date.current,
      to: Date.current
    )
    @first_goal = Goals::Current.goal_for(user: @user, journey: @first)
    @second_goal = Goals::Current.goal_for(user: @user, journey: @second)
  end

  test "relation keeps focused journey battles and ad-hoc todos only" do
    ad_hoc = @user.daily_todos.create!(
      title: "Errand",
      aspect_key: "career",
      scheduled_on: Date.current,
      position: 50,
      lp_reward: 10
    )

    titles = Today::FocusedDayTodos.relation(
      user: @user,
      journey: @first,
      goal: @first_goal,
      on: Date.current
    ).ordered.pluck(:title)

    assert_includes titles, "First fight"
    assert_includes titles, "Errand"
    refute_includes titles, "Second fight"
    assert_includes titles, ad_hoc.title
  end

  test "relation never returns another users todos" do
    other = users(:two)
    seed_climb!(other, area_key: "career", title: "Other", today_mission: "Other fight")

    ids = Today::FocusedDayTodos.relation(
      user: @user,
      journey: @first,
      goal: @first_goal,
      on: Date.current
    ).pluck(:user_id).uniq

    assert_equal [ @user.id ], ids
  end

  test "BattleOpenCount matches focused open list" do
    assert_equal @first.id, @user.primary_focused_journey.id
    assert_equal 1, Today::BattleOpenCount.for(user: @user, on: Date.current)

    Focus::SetJourneys.call(user: @user, journey_ids: [ @second.id ])
    assert_equal 1, Today::BattleOpenCount.for(user: @user, on: Date.current)

    Focus::SetJourneys.call(user: @user, journey_ids: [ @first.id ])
    assert_equal 1, Today::BattleOpenCount.for(user: @user, on: Date.current)
  end

  private

  def seed_second_journey!(title:, area_key:, battle_title:)
    LifeAreas::Select.call(user: @user, keys: [ area_key ])
    area = @user.life_areas.v2_selected.find_by!(key: area_key)
    journey = Journeys::Create.call(
      user: @user,
      life_area: area,
      title: title,
      ideal_scene: "Ideal #{title}",
      current_reality: "Present #{title}",
      next_win: "Next #{title}",
      closer_percent: 20
    )
    goal = @user.strategy_goals.create!(
      user: @user,
      life_area: area,
      life_journey: journey,
      horizon: "goal",
      title: title,
      position: 0
    )
    plan = goal.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "plan", title: "Plan #{title}", position: 0
    )
    project = plan.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "project", title: "Camp #{title}", position: 0
    )
    project.children.create!(
      user: @user, life_area: area, life_journey: journey,
      horizon: "day", title: battle_title, scheduled_on: Date.current, position: 0
    )
    journey
  end
end
