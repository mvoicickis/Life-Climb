require "test_helper"

class DailyBattlePlanTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "money",
      title: "Financial freedom",
      ideal_scene: "Calm savings and no money stress.",
      current_reality: "Building a budget habit.",
      next_win: "Launch Beta",
      today_mission: "Review my budget",
      closer_percent: 36
    )
  end

  test "home shows premium battle hierarchy" do
    get dashboard_path
    assert_response :success
    assert_match(/Today/i, response.body)
    assert_match(/Battle/i, response.body)
    assert_match(/Goal/i, response.body)
    assert_match(/Action Points/i, response.body)
    assert_match(/Strategy Points/i, response.body)
    assert_match(/One mountain\. Today.?s battle/i, response.body)
    assert_match(/Complete Battle/i, response.body)
    assert_match(/Review my budget/i, response.body)
    assert_match(/Financial freedom/i, response.body)
    assert_match(/lp-dash-nav/i, response.body)
    assert_select ".lp-dash-hero__mountain"
    assert_select ".lp-dash-project", count: 0
    assert_no_match(/Life Tree|Open Life/i, response.body)
    assert_no_match(/Daily Battle Plan/i, response.body)
    assert_no_match(/\bAP\b/, response.body)
    assert_no_match(/>\s*SP\s*</, response.body)
  end

  test "hero uses strategy season goal when present" do
    journey = @user.primary_focused_journey
    area = journey.life_area
    @user.strategy_goals.create!(
      life_area: area, life_journey: journey, horizon: "goal",
      title: "Become debt-free", position: 0
    )

    get dashboard_path
    assert_response :success
    assert_match(/Become debt-free/i, response.body)
    assert_select ".lp-dash-hero__mountain-caption"
    # Progress appears once in hero pct — art has no closer duplicate
    assert_select ".lp-dash-hero__pct", count: 1
    assert_select ".lp-dash-hero__area-closer", count: 0
  end

  test "can add and complete a money todo" do
    post daily_todos_url, params: {
      daily_todo: { title: "Cancel unused subscription", aspect_key: "money" }
    }
    assert_redirected_to dashboard_path
    todo = @user.daily_todos.for_day.last
    assert_equal "Cancel unused subscription", todo.title
    assert_equal "money", todo.aspect_key
    assert_equal GameRules::BATTLE_TODO_LP, todo.lp_reward

    post complete_daily_todo_url(todo)
    assert todo.reload.completed?

    get dashboard_path
    assert_match(/Cancel unused subscription/i, response.body)
  end

  test "complete battle finishes open mission and todos" do
    @user.daily_todos.create!(
      title: "Track spending",
      aspect_key: "money",
      scheduled_on: Date.current
    )

    before = @user.reload.total_points
    post battle_completion_url
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match(/Battle complete/i, flash[:notice].to_s + response.body)

    assert @user.daily_todos.for_day.incomplete.none?
    mission = @user.missions.for_day.primary.order(:id).last
    assert mission.completed?
    assert_operator @user.reload.total_points, :>, before
  end

  test "home always shows add form and supports five or more todos" do
    titles = [
      "Finish Dashboard UI",
      "Workout",
      "Read Ruby",
      "Go on date",
      "Plan tomorrow"
    ]

    titles.each do |title|
      post daily_todos_url, params: {
        daily_todo: { title: title, aspect_key: "money" }
      }
      assert_redirected_to dashboard_path
    end

    assert_equal 5, @user.daily_todos.for_day.count

    get dashboard_path
    assert_response :success
    titles.each { |title| assert_match(/#{Regexp.escape(title)}/i, response.body) }
    assert_match(/A few small wins/i, response.body)
    assert_no_match(/lp-dash-add-wrap/i, response.body)

    expected_reward = (5 * GameRules::BATTLE_TODO_LP) + @user.missions.for_day.primary.incomplete.first.lp_reward
    assert_match(/\+#{expected_reward}/, response.body)
  end

  test "daily todo soft cap blocks more than twelve" do
    GameRules::MAX_DAILY_TODOS.times do |i|
      @user.daily_todos.create!(
        title: "Task #{i + 1}",
        aspect_key: "money",
        scheduled_on: Date.current
      )
    end

    post daily_todos_url, params: {
      daily_todo: { title: "One too many", aspect_key: "money" }
    }
    assert_redirected_to dashboard_path
    assert_match(/battle is full/i, flash[:alert].to_s)
    assert_equal GameRules::MAX_DAILY_TODOS, @user.daily_todos.for_day.count
  end
end
