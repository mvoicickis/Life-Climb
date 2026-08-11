# frozen_string_literal: true

require "test_helper"

class ProgressPageTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "money",
      title: "Financial freedom",
      ideal_scene: "Calm savings",
      current_reality: "Budgeting",
      next_win: "Emergency fund",
      today_mission: "Track spending",
      closer_percent: 25
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
  end

  test "journey page renders mountain points and activity" do
    get life_points_path
    assert_response :success
    assert_match(/Journey/i, response.body)
    assert_match(/How far have you come/i, response.body)
    assert_match(/Action Points/i, response.body)
    assert_match(/Planning points/i, response.body)
    assert_match(/Mountain Summary/i, response.body)
    assert_match(/See weekly activity/i, response.body)
    assert_match(/Activity/i, response.body)
    assert_match(/7 Days/i, response.body)
    assert_match(/Weekly activity/i, response.body)
    assert_match(/Achievements/i, response.body)
    assert_match(/lp-dash-nav/i, response.body)
    assert_select ".lp-dash-nav__link.is-active", text: /Journey/i
    assert_no_match(/Climb progress/i, response.body)
    assert_select ".lp-progress-donut__center span", text: /Action Points|AP/i
  end

  test "journey mountain percent matches today when strategy goal exists" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Become debt-free", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Become Job Ready", position: 0
    )
    other_plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Kill debt", position: 1
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Portfolio", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: other_plan, horizon: "project", title: "Budget", position: 0
    )
    project.complete!
    Strategy::SyncCompletion.call(project: project)

    expected = goal.reload.progress_percent.to_i

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-header .lp-dash-bar__fill[style=?]", "width: #{expected}%"

    get life_points_path
    assert_response :success
    assert_select ".lp-journey-hero .lp-dash-hero__pct", text: /#{expected}\s*%/
    assert_match(/Become debt-free/i, response.body)
    assert_match(/Plans Completed/i, response.body)
    assert_match(/Current Expedition/i, response.body)
    assert_match(/Become Job Ready|Kill debt/i, response.body)
    assert_no_match(/\b#{@journey.closer_percent.round}%\b/, response.body) if @journey.closer_percent.round != expected
  end

  test "period query updates selected chip" do
    get life_points_path(period: "30d")
    assert_response :success
    assert_match(/period=30d.*is-active|is-active.*30 Days/i, response.body)
  end

  test "nav labels are mountain today journey you" do
    get life_points_path
    assert_select ".lp-dash-nav__link", text: /Today/i
    assert_select ".lp-dash-nav__link", text: /Mountain/i
    assert_select ".lp-dash-nav__link", text: /Habits/i
    assert_select ".lp-dash-nav__link", text: /Journey/i
    assert_select ".lp-dash-nav__link", text: /You/i
    assert_select ".lp-dash-nav__link", text: /\A\s*Progress\s*\z/, count: 0
  end

  test "journey trends show battles section and omit empty quantified habits" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Season", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Path", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project", title: "Camp", position: 0
    )
    leaf = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "project", title: "Steps", position: 0
    )
    day = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: leaf, horizon: "day",
      title: "Ship it", scheduled_on: Date.current, position: 0
    )
    @user.daily_todos.create!(
      title: "Ship it",
      aspect_key: @area.key,
      scheduled_on: Date.current,
      strategy_goal: day,
      completed_at: Time.current,
      position: 0
    )

    get life_points_path
    assert_response :success
    assert_match(/Your climb trends/i, response.body)
    assert_match(/Battles per week/i, response.body)
    assert_match(/More Battles this week than last|About the same as last week|A bit quieter than last week/i, response.body)
    assert_select ".lp-journey-trends"
    assert_select "[data-controller='journey-trends']"
    assert_select ".lp-journey-trends__quantified", count: 0
    assert_select ".lp-journey-trends__habits", count: 0
    assert_select "canvas[data-journey-trends-target='quantified']", count: 0
    assert_match(/See weekly activity/i, response.body)
    assert_match(/Weekly activity/i, response.body)
  end

  test "journey trends render quantified graphs and linked habit week" do
    goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Season", position: 0
    )
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: goal, horizon: "plan", title: "Path", position: 0
    )
    pages = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Read the book", position: 0, target_amount: 100, unit: "pages"
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Save cash", position: 1, target_amount: 500, unit: "€"
    )
    @user.strategy_quantity_logs.create!(
      strategy_goal: pages, amount: 12, unit: "pages", logged_on: Date.current
    )
    @user.habits.create!(
      name: "Linked stretch",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "times",
      show_on_home: true,
      position: 1,
      stat_type: "growth",
      life_journey: @journey
    )
    pages_habit = @user.habits.create!(
      name: "Income",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "€",
      show_on_home: true,
      position: 2,
      stat_type: "growth",
      life_journey: @journey
    )
    @user.daily_logs.create!(habit: pages_habit, logged_on: Date.current, amount: 45)
    @user.habits.create!(
      name: "Unlinked walk",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "times",
      show_on_home: true,
      position: 3,
      stat_type: "growth"
    )

    get life_points_path
    assert_response :success
    assert_match(/Project totals/i, response.body)
    assert_match(/Read the book/i, response.body)
    assert_match(/Save cash/i, response.body)
    assert_match(/Target 100 pages/i, response.body)
    assert_match(/Target 500 €/i, response.body)
    assert_select "canvas[data-journey-trends-target='quantified']", count: 2
    assert_match(/Habits this week/i, response.body)
    assert_match(/Linked stretch/i, response.body)
    assert_match(/Income/i, response.body)
    assert_select ".lp-journey-habits__row", text: /Unlinked walk/i, count: 0
    assert_select ".lp-journey-habits__row", count: 2
    assert_select ".lp-journey-habits__row.is-quantity", count: 1
    assert_select ".lp-journey-habits__day", count: 14
    assert_select ".lp-journey-habits__amount", text: "45"
    assert_select ".lp-journey-habits__unit", text: "€"
    assert_select ".lp-journey-stats__card", text: /Unlinked walk/i
  end

  test "your stats section absent without areas or unfiled trackers" do
    @user.habits.destroy_all
    @user.areas.destroy_all

    get life_points_path
    assert_response :success
    assert_select ".lp-journey-stats", count: 0
    assert_match(/Achievements/i, response.body)
  end

  test "your stats shows area tracker with labeled chart and state chip" do
    @user.habits.destroy_all
    area = @user.areas.create!(name: "Health", position: 1)
    habit = @user.habits.create!(
      name: "Steps",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "steps",
      show_on_home: true,
      position: 1,
      stat_type: "growth",
      area: area,
      state: "good",
      state_label_good: "Moving"
    )
    @user.daily_logs.create!(habit: habit, logged_on: Date.current, amount: 4000)

    get life_points_path
    assert_response :success
    assert_match(/Your climb trends|Achievements/i, response.body)
    assert_select ".lp-journey-stats"
    assert_match(/Your stats/i, response.body)
    assert_match(/Health/i, response.body)
    assert_match(/Steps/i, response.body)
    assert_match(/Moving/i, response.body)
    assert_select ".lp-areas__state.is-good", text: /Moving/
    assert_select ".lp-journey-stats__list"
    assert_select ".lp-journey-stats__chart canvas[data-journey-stats-target='chart'][data-habit-id='#{habit.id}']"
    assert_select "[data-controller='journey-stats'][data-journey-stats-series-value]"
    assert_match(/#{Regexp.escape(I18n.l(Date.current, format: "%b %-d"))}/, response.body)
    assert_select ".lp-journey-stats svg.lp-tracker-spark", count: 0
    assert_select ".lp-journey-stats__spark", count: 0
  end

  test "hide removes tracker from journey stats but keeps habit" do
    @user.habits.destroy_all
    area = @user.areas.create!(name: "Finance", position: 1)
    habit = @user.habits.create!(
      name: "Savings",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "€",
      show_on_home: true,
      position: 1,
      stat_type: "growth",
      area: area
    )

    patch habit_path(habit), params: {
      return_to: "journey",
      habit: { hidden_from_dashboard: true }
    }
    assert_redirected_to life_points_path
    assert habit.reload.hidden_from_dashboard?

    get life_points_path
    assert_response :success
    assert_select ".lp-journey-stats"
    assert_select ".lp-journey-stats__card", text: /Savings/, count: 0
    assert Habit.exists?(habit.id)
  end

  test "create tracker from journey dialog returns to progress" do
    area = @user.areas.create!(name: "Home", position: 1)

    assert_difference -> { @user.habits.count }, 1 do
      post habits_path, params: {
        return_to: "journey",
        habit: {
          name: "Morning pages",
          unit: "pages",
          area_id: area.id,
          points: 5,
          frequency: "daily",
          active: true,
          show_on_home: true,
          stat_type: "growth"
        }
      }
    end
    assert_redirected_to life_points_path

    get life_points_path
    assert_response :success
    assert_match(/Morning pages/i, response.body)
    assert_select ".lp-journey-stats__card", text: /Morning pages/
  end

  test "area move up and down changes order on progress" do
    first = @user.areas.create!(name: "Alpha", position: 1)
    second = @user.areas.create!(name: "Beta", position: 2)

    patch move_area_path(second), params: { direction: "up", return_to: "journey" }
    assert_redirected_to life_points_path
    assert_equal [ "Beta", "Alpha" ], @user.areas.ordered.pluck(:name)

    get life_points_path
    assert_response :success
    body = response.body
    assert body.index(">Beta<") < body.index(">Alpha<")

    patch move_area_path(second), params: { direction: "down", return_to: "journey" }
    assert_redirected_to life_points_path
    assert_equal [ "Alpha", "Beta" ], @user.areas.ordered.pluck(:name)
  end
end
