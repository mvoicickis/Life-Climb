# frozen_string_literal: true

require "test_helper"

class WeeklyPlannersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "App live",
      current_reality: "Building",
      next_win: "Launch",
      today_mission: "Write tests",
      closer_percent: 20,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ])
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "plan", title: "Main trail", position: 0
    )
    @project = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Resume", position: 0
    )
    @journey.update!(commitment_battle_count: 3)
  end

  test "show renders build_items" do
    travel_to Date.new(2026, 8, 10) do
      get weekly_planner_path(plan_id: @plan.id)
      assert_response :success
      assert_match(/What do you want to work on this week/i, response.body)
      assert_match(/Name the work/i, response.body)
      assert_match(/Continue/i, response.body)
      assert_select ".lp-weekly-planner__already", count: 0
    end
  end

  test "show lists already scheduled titles for this week" do
    travel_to Date.new(2026, 8, 10) do
      [ Date.new(2026, 8, 10), Date.new(2026, 8, 11) ].each_with_index do |day, i|
        @user.daily_todos.create!(
          title: "Improve German",
          scheduled_on: day,
          position: i,
          aspect_key: @area.key,
          lp_reward: GameRules::BATTLE_TODO_LP
        )
      end

      get weekly_planner_path(plan_id: @plan.id)
      assert_response :success
      assert_select ".lp-weekly-planner__already"
      assert_match(/Already this week/i, response.body)
      assert_match(/Improve German · 2 days/i, response.body)
    end
  end

  test "step 1 add_item without JS re-renders the item in the list" do
    travel_to Date.new(2026, 8, 10) do
      get weekly_planner_path(plan_id: @plan.id)
      post weekly_planner_path(plan_id: @plan.id), params: {
        intent: "add_item",
        value: "Install Linux"
      }
      assert_redirected_to weekly_planner_path(plan_id: @plan.id)
      follow_redirect!
      assert_response :success
      assert_match(/Install Linux/i, response.body)
      assert_match(/Continue with 1 item/i, response.body)
      assert_select "[data-weekly-planner-items-target='row']", text: /Install Linux/
    end
  end

  test "free-text happy path creates days and redirects to mountain" do
    travel_to Date.new(2026, 8, 10) do
      post weekly_planner_path(plan_id: @plan.id), params: {
        intent: "add_item",
        value: "Ship landing"
      }
      follow_redirect!
      post weekly_planner_path(plan_id: @plan.id), params: { intent: "continue" }
      assert_redirected_to weekly_planner_path(plan_id: @plan.id)
      follow_redirect!
      assert_match(/Which days suit you/i, response.body)
      assert_match(/Item 1 of 1/i, response.body)
      assert_no_match(/=>/, response.body)
      assert_no_match(/\{"title"/, response.body)

      date = Strategy::WeeklyPlanner::Definition.eligible_dates(@user).first
      post weekly_planner_path(plan_id: @plan.id), params: { dates: [ date.iso8601 ] }
      assert_redirected_to life_journey_path(@journey)
      follow_redirect!
      notice = flash[:notice].to_s + response.body
      assert_match(/1 thing set across 1 day slot/i, notice)
      assert_no_match(/=>/, notice)
      assert_no_match(/\{"title"/, notice)

      assert_equal 1, @user.strategy_goals.for_kind("day").where(title: "Ship landing").count
      assert @user.daily_todos.for_day(date).exists?(title: "Ship landing")
    end
  end

  test "continue with nested items title params stores plain string titles" do
    travel_to Date.new(2026, 8, 10) do
      post weekly_planner_path(plan_id: @plan.id), params: {
        intent: "continue",
        items: [ { title: "Get a job" } ]
      }
      assert_redirected_to weekly_planner_path(plan_id: @plan.id)
      follow_redirect!
      assert_response :success
      assert_match(/Get a job/, response.body)
      assert_no_match(/=>/, response.body)
      assert_no_match(/\{"title"/, response.body)

      cursor = Strategy::WeeklyPlanner::Cursor.load(@journey.reload)
      assert_equal "Get a job", cursor["items"].first["title"]

      date = Strategy::WeeklyPlanner::Definition.eligible_dates(@user).first
      post weekly_planner_path(plan_id: @plan.id), params: { dates: [ date.iso8601 ] }
      assert_redirected_to life_journey_path(@journey)
      goal = @user.strategy_goals.for_kind("day").where(scheduled_on: date).order(:id).last
      assert_equal "Get a job", goal.title
      refute_includes goal.title, "=>"
    end
  end

  test "done flash summarizes counts without listing titles" do
    travel_to Date.new(2026, 8, 10) do
      post weekly_planner_path(plan_id: @plan.id), params: { intent: "continue", items: [ "One day only" ] }
      follow_redirect!
      date = Strategy::WeeklyPlanner::Definition.eligible_dates(@user).first
      post weekly_planner_path(plan_id: @plan.id), params: { dates: [ date.iso8601 ] }
      assert_redirected_to life_journey_path(@journey)
      assert_match(/1 thing set across 1 day slot/i, flash[:notice].to_s)
      assert_match(/They’ll show on Today/i, flash[:notice].to_s)
      assert_no_match(/One day only/, flash[:notice].to_s)
    end
  end

  test "sunday nearly-done screen offers mountain CTA without dead-end" do
    travel_to Date.new(2026, 8, 16) do
      get weekly_planner_path(plan_id: @plan.id)
      assert_response :success
      assert_match(/almost wrapped/i, response.body)
      assert_match(/Back to Mountain/i, response.body)
      assert_no_match(/No open days left this week/i, response.body)
      assert_select "a[href=?]", life_journey_path(@journey)
    end
  end

  test "exhausted mid-week shows calm dead-end" do
    travel_to Date.new(2026, 8, 12) do
      (Date.current..Date.current.end_of_week).each do |date|
        GameRules::MAX_DAILY_TODOS.times do |i|
          @user.daily_todos.create!(
            title: "Fill #{date}-#{i}",
            scheduled_on: date,
            position: i,
            aspect_key: @area.key,
            lp_reward: GameRules::BATTLE_TODO_LP
          )
        end
      end

      get weekly_planner_path(plan_id: @plan.id)
      assert_response :success
      assert_match(/No open days left this week/i, response.body)
      assert_match(/Back to Mountain/i, response.body)
    end
  end

  test "path menu includes Plan this week link" do
    travel_to Date.new(2026, 8, 10) do
      get life_journey_path(@journey, goal_id: @goal.id, plan_id: @plan.id)
      assert_response :success
      assert_select "a[href=?]", weekly_planner_path(plan_id: @plan.id, new_week: 1)
    end
  end
end
