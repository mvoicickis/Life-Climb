# frozen_string_literal: true

require "test_helper"

class Progress::JourneyTrendsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Ship LifePoints",
      ideal_scene: "Calm productive days",
      current_reality: "Building daily",
      next_win: "Launch Beta",
      today_mission: "Finish progress page",
      closer_percent: 40
    )
    @user.reload
    @journey = @user.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, horizon: "goal", title: "Season", position: 0
    )
    @plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan", title: "Path", position: 0
    )
  end

  test "returns nil battles and empty camps/habits when journey is quiet" do
    data = Progress::JourneyTrends.call(user: @user, journey: @journey)

    assert_nil data[:battles]
    assert_equal [], data[:camps]
    assert_equal [], data[:habits]
  end

  test "counts completed battles by week for this journey only" do
    day = create_day!("Journal")
    other_journey = @user.life_journeys.create!(
      life_area: @area,
      title: "Other mountain",
      ideal_scene: "Elsewhere",
      current_reality: "Other",
      next_win: "Other win",
      gap_percent: 80,
      status: "active"
    )
    other_goal = @user.strategy_goals.create!(
      life_area: @area, life_journey: other_journey, horizon: "goal", title: "Other", position: 1
    )
    other_plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: other_journey, parent: other_goal, horizon: "plan", title: "Other path", position: 0
    )
    other_project = @user.strategy_goals.create!(
      life_area: @area, life_journey: other_journey, parent: other_plan, horizon: "project", title: "Other camp", position: 0
    )
    other_day = @user.strategy_goals.create!(
      life_area: @area, life_journey: other_journey, parent: other_project,
      horizon: "day", title: "Other battle", scheduled_on: Date.current, position: 0
    )

    this_monday = Date.current.beginning_of_week(:monday)
    last_monday = this_monday - 7

    create_completed_todo!(day, completed_at: this_monday.in_time_zone + 10.hours)
    create_completed_todo!(day, completed_at: this_monday.in_time_zone + 12.hours, title: "Second", scheduled_on: this_monday + 1)
    create_completed_todo!(day, completed_at: last_monday.in_time_zone + 10.hours, title: "Last week", scheduled_on: last_monday)
    create_completed_todo!(other_day, completed_at: this_monday.in_time_zone + 11.hours, title: "Noise", scheduled_on: this_monday + 2)

    data = Progress::JourneyTrends.call(user: @user, journey: @journey)

    assert data[:battles]
    assert_equal 8, data[:battles][:weeks].size
    assert_equal 2, data[:battles][:weeks].last[:value]
    assert_equal 1, data[:battles][:weeks][-2][:value]
    assert_equal :up, data[:battles][:comparison]
  end

  test "battle comparison is flat and down" do
    day = create_day!("Practice")
    this_monday = Date.current.beginning_of_week(:monday)
    last_monday = this_monday - 7

    create_completed_todo!(day, completed_at: this_monday.in_time_zone + 10.hours)
    create_completed_todo!(day, completed_at: last_monday.in_time_zone + 10.hours, title: "Prior", scheduled_on: last_monday)

    data = Progress::JourneyTrends.call(user: @user, journey: @journey)
    assert_equal :flat, data[:battles][:comparison]

    create_completed_todo!(day, completed_at: last_monday.in_time_zone + 12.hours, title: "Prior 2", scheduled_on: last_monday + 1)
    data = Progress::JourneyTrends.call(user: @user, journey: @journey)
    assert_equal :down, data[:battles][:comparison]
  end

  test "quantified camps get daily weekly and monthly cumulative series" do
    pages = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Read the book", position: 0, target_amount: 100, unit: "pages"
    )
    euros = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Save cash", position: 1, target_amount: 500, unit: "€"
    )

    this_monday = Date.current.beginning_of_week(:monday)
    @user.strategy_quantity_logs.create!(
      strategy_goal: pages, amount: 10, unit: "pages", logged_on: this_monday - 14
    )
    @user.strategy_quantity_logs.create!(
      strategy_goal: pages, amount: 15, unit: "pages", logged_on: this_monday - 3
    )
    @user.strategy_quantity_logs.create!(
      strategy_goal: euros, amount: 50, unit: "€", logged_on: this_monday
    )

    data = Progress::JourneyTrends.call(user: @user, journey: @journey)

    assert_equal 2, data[:camps].size
    titles = data[:camps].map { |s| s[:title] }
    assert_includes titles, "Read the book"
    assert_includes titles, "Save cash"

    pages_camp = data[:camps].find { |s| s[:project_id] == pages.id }
    assert_equal "quantified", pages_camp[:kind]
    assert_equal 100.0, pages_camp[:target]
    assert_equal "pages", pages_camp[:unit]
    assert_equal 7, pages_camp[:series][:daily].size
    assert_equal 8, pages_camp[:series][:weekly].size
    assert_equal 6, pages_camp[:series][:monthly].size
    assert_equal 25.0, pages_camp[:series][:weekly].last[:value]
    assert_equal 25.0, pages_camp[:series][:weekly][-2][:value]
    assert_equal 10.0, pages_camp[:series][:weekly][-3][:value]

    euros_camp = data[:camps].find { |s| s[:project_id] == euros.id }
    assert_equal 50.0, euros_camp[:series][:weekly].last[:value]
    assert_equal 0.0, euros_camp[:series][:weekly][-2][:value]
  end

  test "binary camps include battle win series and stat label" do
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "Ship portfolio", position: 0
    )
    day = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: "Draft case study", scheduled_on: Date.current, position: 0
    )

    this_monday = Date.current.beginning_of_week(:monday)
    create_completed_todo!(day, completed_at: this_monday.in_time_zone + 10.hours)
    create_completed_todo!(day, completed_at: (this_monday - 7).in_time_zone + 10.hours, title: "Prior", scheduled_on: this_monday - 7)

    data = Progress::JourneyTrends.call(user: @user, journey: @journey)
    camp = data[:camps].find { |c| c[:project_id] == project.id }

    assert_equal "battles", camp[:kind]
    assert_match(/2 battles won/i, camp[:stat_label])
    assert_nil camp[:target_line]
    assert_equal 2.0, camp[:series][:weekly].last[:value]
    assert_equal 1.0, camp[:series][:weekly][-2][:value]
  end

  test "habits this week only include linked active habits" do
    linked = @user.habits.create!(
      name: "Morning stretch",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "times",
      show_on_home: true,
      position: 1,
      stat_type: "growth",
      life_journey: @journey
    )
    quantity = @user.habits.create!(
      name: "Read pages",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "pages",
      show_on_home: true,
      position: 2,
      stat_type: "growth",
      life_journey: @journey
    )
    @user.habits.create!(
      name: "Unlinked",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "times",
      show_on_home: true,
      position: 3,
      stat_type: "growth"
    )

    monday = Date.current.beginning_of_week(:monday)
    @user.completions.create!(habit: linked, completed_on: monday, points_awarded: 5)
    @user.daily_logs.create!(habit: quantity, logged_on: monday + 1, amount: 12)

    data = Progress::JourneyTrends.call(user: @user, journey: @journey)

    assert_equal 2, data[:habits].size
    names = data[:habits].map { |h| h[:name] }
    assert_includes names, "Morning stretch"
    assert_includes names, "Read pages"
    assert_not_includes names, "Unlinked"

    stretch = data[:habits].find { |h| h[:habit_id] == linked.id }
    assert_equal false, stretch[:quantity]
    assert_equal 7, stretch[:days].size
    assert stretch[:days][0][:done]
    assert_not stretch[:days][1][:done]
    assert_nil stretch[:days][0][:amount]

    pages = data[:habits].find { |h| h[:habit_id] == quantity.id }
    assert_equal true, pages[:quantity]
    assert_equal "pages", pages[:unit]
    assert_not pages[:days][0][:done]
    assert pages[:days][1][:done]
    assert_equal 12, pages[:days][1][:amount]
    assert_nil pages[:days][0][:amount]
  end

  test "habits this week omits hidden_from_dashboard habits" do
    visible = @user.habits.create!(
      name: "Visible walk",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "steps",
      show_on_home: true,
      position: 1,
      stat_type: "growth",
      life_journey: @journey
    )
    hidden = @user.habits.create!(
      name: "Hidden walk",
      points: 5,
      frequency: "daily",
      active: true,
      unit: "steps",
      show_on_home: true,
      position: 2,
      stat_type: "growth",
      life_journey: @journey,
      hidden_from_dashboard: true
    )

    data = Progress::JourneyTrends.call(user: @user, journey: @journey)

    names = data[:habits].map { |h| h[:name] }
    assert_includes names, visible.name
    assert_not_includes names, hidden.name
  end

  private

  def create_day!(title)
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @plan, horizon: "project",
      title: "#{title} camp", position: @plan.children.count
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: project, horizon: "day",
      title: title, scheduled_on: Date.current, position: 0
    )
  end

  def create_completed_todo!(day, completed_at:, title: nil, scheduled_on: Date.current)
    @user.daily_todos.create!(
      title: title || day.title,
      aspect_key: @area.key,
      scheduled_on: scheduled_on,
      strategy_goal: day,
      completed_at: completed_at,
      position: @user.daily_todos.where(scheduled_on: scheduled_on).count
    )
  end
end
