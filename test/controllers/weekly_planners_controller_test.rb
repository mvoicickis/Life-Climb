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

  test "show renders pick_source" do
    travel_to Date.new(2026, 8, 10) do
      get weekly_planner_path(plan_id: @plan.id)
      assert_response :success
      assert_match(/What do you want to work on this week/i, response.body)
      assert_match(/Something else/i, response.body)
    end
  end

  test "free-text happy path creates days and redirects to mountain" do
    travel_to Date.new(2026, 8, 10) do
      get weekly_planner_path(plan_id: @plan.id)
      post weekly_planner_path(plan_id: @plan.id), params: { value: "Ship landing" }
      assert_redirected_to weekly_planner_path(plan_id: @plan.id)

      follow_redirect!
      assert_match(/How many days this week/i, response.body)

      post weekly_planner_path(plan_id: @plan.id), params: { value: "2" }
      follow_redirect!
      assert_match(/Which days suit you/i, response.body)

      dates = Strategy::WeeklyPlanner::Definition.eligible_dates(@user).first(2)
      post weekly_planner_path(plan_id: @plan.id), params: { dates: dates.map(&:iso8601) }
      assert_redirected_to life_journey_path(@journey)
      follow_redirect!
      assert_match(/2 days set for Ship landing/i, flash[:notice].to_s + response.body)

      assert_equal 2, @user.strategy_goals.for_kind("day").where(title: "Ship landing").count
      dates.each do |date|
        assert @user.daily_todos.for_day(date).exists?(title: "Ship landing")
      end
    end
  end

  test "done flash uses singular day and pronoun for count 1" do
    travel_to Date.new(2026, 8, 10) do
      get weekly_planner_path(plan_id: @plan.id)
      post weekly_planner_path(plan_id: @plan.id), params: { value: "One day only" }
      follow_redirect!
      post weekly_planner_path(plan_id: @plan.id), params: { value: "1" }
      follow_redirect!
      date = Strategy::WeeklyPlanner::Definition.eligible_dates(@user).first
      post weekly_planner_path(plan_id: @plan.id), params: { dates: [ date.iso8601 ] }
      assert_redirected_to life_journey_path(@journey)
      assert_match(/1 day set for One day only/i, flash[:notice].to_s)
      assert_match(/it’ll show on Today/i, flash[:notice].to_s)
      assert_no_match(/1 days|they’ll/i, flash[:notice].to_s)
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
      assert_select "a[href=?]", weekly_planner_path(plan_id: @plan.id, new_week: 1),
                    text: /Plan this week/i
    end
  end

  test "free-text field is required so empty submit is caught in the browser" do
    travel_to Date.new(2026, 8, 10) do
      get weekly_planner_path(plan_id: @plan.id)
      assert_response :success
      assert_select "input[name=value][required]"
    end
  end

  test "blank answer re-renders pick_source with a visible alert error" do
    travel_to Date.new(2026, 8, 10) do
      get weekly_planner_path(plan_id: @plan.id)
      post weekly_planner_path(plan_id: @plan.id), params: { value: "   " }
      assert_response :unprocessable_entity
      assert_match(/What do you want to work on this week/i, response.body)
      assert_select "[data-weekly-planner-error][role=alert][aria-live=assertive]",
                    text: /short name/i
      assert_select "[data-weekly-planner-error].lp-flash.lp-flash--alert"
    end
  end
end
