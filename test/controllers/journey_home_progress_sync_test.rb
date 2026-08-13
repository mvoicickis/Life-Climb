# frozen_string_literal: true

require "test_helper"

class JourneyHomeProgressSyncTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App in production",
      current_reality: "Still building",
      next_win: "Launch Beta",
      today_mission: "Write one test",
      closer_percent: 20
    )
    @journey = @user.reload.primary_focused_journey
    @journey.update!(
      setup_flags: {
        "goal" => "done", "purpose" => "done", "policy" => "done",
        "approach" => "done", "program" => "done", "milestone" => "done",
        "scenes" => "done", "finished" => "done"
      },
      finished_result: "A live product",
      milestones: [ { "title" => "Launch Beta", "tags" => [ "ship" ] }, { "title" => "First 10 users", "tags" => [ "ship" ] } ],
      next_win: "Launch Beta"
    )
  end

  test "journey today actions appear on home battle" do
    @user.daily_todos.for_day.destroy_all

    patch life_journey_path(@journey), params: {
      layer: "today",
      life_journey: { today_mission: "Deep work" },
      daily_todo_titles: [ "Write tests", "Polish UI" ],
      daily_todo_tags: [ "ship", "ship" ]
    }
    assert_redirected_to life_journey_path(@journey, edit: "today")

    get dashboard_path
    assert_response :success
    assert_match(/Write tests/, response.body)
    assert_match(/Polish UI/, response.body)
    assert_match(/See your mountain/i, response.body)
  end

  test "strategy battle sync marks journey today layer done" do
    @user.daily_todos.for_day.destroy_all
    @journey.update_column(:setup_flags, @journey.setup_flags.merge("today" => nil))

    area = @journey.life_area
    goal = @user.strategy_goals.create!(
      life_area: area, life_journey: @journey, horizon: "goal", title: "Ship", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: area, life_journey: @journey, parent: goal, horizon: "plan", title: "Plan", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: area, life_journey: @journey, parent: plan, horizon: "project", title: "Project", position: 0
    )
    project_leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: area, life_journey: @journey, parent: project_leaf, horizon: "day",
      title: "Call a customer", scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: area)
    Journeys::SyncClimbFromToday.call(user: @user)

    @journey.reload
    assert @journey.layer_done?("today")
    assert_includes @user.daily_todos.for_day.pluck(:title), "Call a customer"
  end

  test "journey closer percent matches home and progress" do
    patch life_journey_path(@journey), params: {
      closer_only: "1",
      life_journey: { closer_percent: 55 }
    }
    assert_redirected_to life_journey_path(@journey)
    @journey.reload
    assert_in_delta 45.0, @journey.gap_percent.to_f, 0.01

    get dashboard_path
    assert_select ".lp-dash-hero", count: 1
    assert_select ".lp-dash-hero__track", count: 1

    get life_points_path
    assert_response :success
    assert_match(/55%/, response.body)
    assert_match(/Mountain Summary/i, response.body)
    assert_match(/Action Points/i, response.body)
  end

  test "countable target logs from home and updates journey closer" do
    target = @journey.journey_targets.create!(
      user: @user,
      title: "Finish the book",
      kind: "count",
      target_value: 100,
      current_value: 0,
      unit: "pages",
      tags: [ "learn" ]
    )
    before = @journey.gap_percent.to_f

    post log_journey_target_path(target), params: { amount: 5 }
    assert_redirected_to dashboard_path
    target.reload
    assert_in_delta 5.0, target.current_value.to_f, 0.01
    @journey.reload
    assert_operator @journey.gap_percent.to_f, :<, before

    get dashboard_path
    assert_match(/Finish the book/, response.body)
    assert_match(%r{5/100}, response.body)
  end

  test "tagged approaches save tags on list items" do
    @journey.update!(
      setup_flags: {
        "goal" => "done", "purpose" => "done", "policy" => "done"
      },
      approaches: []
    )

    patch life_journey_path(@journey), params: {
      layer: "approach",
      life_journey: {
        approaches: [ "Pay the meter", "Cut costs" ],
        approaches_tags: [ "meter", "meter" ]
      }
    }
    assert_redirected_to life_journey_path(@journey, edit: "program")
    @journey.reload
    items = @journey.approaches_items
    assert_equal "Pay the meter", items.first["title"]
    assert_includes items.first["tags"], "meter"
  end
end
