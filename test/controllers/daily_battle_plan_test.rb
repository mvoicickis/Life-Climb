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
      next_win: nil,
      today_mission: "Review my budget",
      closer_percent: 6
    )
  end

  test "home shows battle plan and filters by aspect tag" do
    get dashboard_path(aspect: "money")
    assert_response :success
    assert_match(/Daily Battle Plan/i, response.body)
    assert_match(/This improves/i, response.body)
  end

  test "can add and complete a money todo" do
    post daily_todos_url, params: {
      daily_todo: { title: "Cancel unused subscription", aspect_key: "money" }
    }
    assert_redirected_to dashboard_path(aspect: "money")
    todo = @user.daily_todos.for_day.last
    assert_equal "Cancel unused subscription", todo.title
    assert_equal "money", todo.aspect_key

    post complete_daily_todo_url(todo)
    assert todo.reload.completed?

    get dashboard_path(aspect: "money")
    assert_match(/Cancel unused subscription/i, response.body)
  end

  test "career todo does not show under money filter by default markup" do
    @user.daily_todos.create!(
      title: "Apply to one job",
      aspect_key: "career",
      scheduled_on: Date.current
    )
    @user.daily_todos.create!(
      title: "Track spending",
      aspect_key: "money",
      scheduled_on: Date.current
    )

    get dashboard_path(aspect: "money")
    assert_match(/Track spending/i, response.body)
    # Career item is in the DOM but hidden until Career tag is selected
    assert_match(/data-aspect="career"/, response.body)
    assert_match(/Apply to one job/i, response.body)
  end
end
