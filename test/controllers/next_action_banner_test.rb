# frozen_string_literal: true

require "test_helper"

class NextActionBannerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(character: "fox", climb_streak_days: 0, climb_streak_on: nil)
    sign_in_as @user
    Onboarding::Run.call(
      user: @user,
      area_key: "career",
      title: "Find a job",
      ideal_scene: "Hired",
      current_reality: "Searching",
      today_mission: "Plan the path",
      closer_percent: 10,
      route_mission: true
    )
    @journey = @user.reload.primary_focused_journey
    @area = @journey.life_area
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 10, 0, 0)
  end

  teardown do
    travel_back
  end

  test "plan_route banner on Today when goal has no plans" do
    clear_setup_gap!

    get dashboard_path
    assert_response :success

    assert_banner_state(:plan_route, tone: :steady)
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.plan_route.cta")
  end

  test "set_today banner when spine exists without daily todos" do
    build_spine_without_cascade!
    seed_today_habits!(@journey.commitment_habit_count)
    @journey.update!(commitment_battle_count: 0)

    get dashboard_path
    assert_response :success

    assert_banner_state(:set_today, tone: :steady)
    assert_select "a.lp-cta", count: 0
    assert_select "[data-commitment-progress]", minimum: 1
  end

  test "complete_battle banner includes todo title with steady tone before overdue hour" do
    build_spine_and_cascade!(title: "Send five emails")
    clear_setup_gap!

    get dashboard_path
    assert_response :success

    assert_banner_state(:complete_battle, tone: :steady)
    assert_select ".lp-dash-next__title", text: /Send five emails/
    assert_select "a.lp-cta", count: 0
    assert_select "[data-commitment-progress]", minimum: 1
  end

  test "battle_overdue banner uses urgent tone after overdue hour" do
    build_spine_and_cascade!(title: "Send five emails")
    clear_setup_gap!
    travel_to Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 19, 0, 0)

    get dashboard_path
    assert_response :success

    assert_banner_state(:battle_overdue, tone: :urgent)
    assert_select ".lp-dash-next__title", text: /Send five emails/
    assert_select "a.lp-cta", count: 0
    assert_select "[data-commitment-progress]", minimum: 1
  end

  test "commitment_gap panel shows chips, quiet Drop to Easy, and Mountain only when camps short" do
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
    seed_today_habits!(3)
    3.times do |n|
      @user.daily_todos.create!(
        title: "Timed #{n}", scheduled_on: Date.current, aspect_key: "career",
        start_time: "09:00", end_time: "10:00", position: 40 + n
      )
    end

    get dashboard_path
    assert_response :success

    assert_select "#commitment-gap-panel.is-stuck[data-next-action-key=commitment_gap]", count: 1
    assert_select "[data-battles-count]", text: "0/3"
    assert_select "[data-habits-count]", text: /\d+\/3/
    assert_select "a.lp-cta", count: 0
    assert_select ".lp-commitment-gap__link", text: /Drop to Easy/i
    assert_select "a.lp-commitment-gap__link[href=?]", life_journey_path(@journey),
                  text: /Open Mountain/i
    assert_select "[data-commitment-progress]", count: 0
    assert_select "input[type=time].lp-input", minimum: 1
    assert_select "input.lp-commitment-gap__qty-check[type=checkbox]", count: 1
  end

  test "setup_gap panel on Easy hides Drop to Easy and shows habit form" do
    Today::Commitment.apply_preset!(@journey, "easy")
    @user.habits.active.on_home.destroy_all
    @user.daily_todos.create!(
      title: "First fight", scheduled_on: Date.current, aspect_key: "career",
      position: 1
    )

    get dashboard_path
    assert_response :success

    assert_select "#commitment-gap-panel.is-stuck[data-next-action-key=setup_gap]", count: 1
    assert_select ".lp-commitment-gap__link", text: /Drop to Easy/i, count: 0
    assert_select "form[action=?]", habits_path, minimum: 1
    assert_select "[data-commitment-progress]", minimum: 1
  end

  test "setup_gap set_time form posts to daily_todo_path" do
    Today::Commitment.apply_preset!(@journey, "easy")
    seed_today_habits!(1)
    todo = @user.daily_todos.create!(
      title: "Untimed fight", scheduled_on: Date.current, aspect_key: "career",
      position: 1
    )

    get dashboard_path
    assert_response :success

    assert_select "#commitment-gap-panel[data-next-action-key=setup_gap]", count: 1
    assert_select "form[action=?]", daily_todo_path(todo)
    assert_select "input[name='daily_todo[start_time]']", count: 1
    assert_select "input[name='daily_todo[end_time]']", count: 1
  end

  test "setup_gap on Medium keeps Drop to Easy" do
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )
    @user.habits.active.on_home.destroy_all

    get dashboard_path
    assert_response :success

    assert_select "#commitment-gap-panel[data-next-action-key=setup_gap]", count: 1
    assert_select ".lp-commitment-gap__link", text: /Drop to Easy/i, count: 1
  end

  test "Drop to Easy from commitment_gap returns to Today and sets Easy" do
    @user.habits.active.on_home.update_all(show_on_home: false)
    @journey.update!(
      commitment_key: "medium",
      commitment_name: "Medium",
      commitment_habit_count: 3,
      commitment_battle_count: 3
    )

    patch commitment_settings_path, params: { commitment_key: "easy", return_to: "today" }
    assert_redirected_to dashboard_path
    assert_equal "easy", @journey.reload.commitment_key
    assert_equal 1, @journey.commitment_habit_count
  end

  test "confirm_camp banner when ProjectCheckQueue has a pending project" do
    build_spine_and_cascade!(title: "Send five emails")
    clear_setup_gap!
    todo = @user.daily_todos.for_day(Date.current).find_by!(title: "Send five emails")

    post complete_daily_todo_path(todo)
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success

    assert_banner_state(:confirm_camp, tone: :steady)
    assert_select "a.lp-cta", count: 0
    assert_select "[data-commitment-progress]", minimum: 1
  end

  test "day_won banner when todos are done and no camp confirmation pending" do
    build_spine_and_cascade!(title: "Send five emails")
    clear_setup_gap!
    complete_all_todos!

    get dashboard_path
    assert_response :success

    assert_banner_state(:day_won, tone: :steady)
    assert_select "a.lp-cta", text: I18n.t("strategy.next_action.day_won.cta")
    assert_select "[data-commitment-progress]", minimum: 1
  end

  test "banner absent when journey has no goal" do
    @goal.destroy!

    get dashboard_path
    assert_response :success

    assert_select ".lp-dash-next", count: 0
  end

  test "stylesheet keeps single-row truncation contract for long headlines" do
    css = Rails.root.join("app/assets/tailwind/application.css").read
    block = css[/\.lp-dash-next,\s*\.lp-dash-next\.lp-glass--pad\s*\{[^}]+\}/m]
    title = css[/\.lp-dash-next__title\s*\{[^}]+\}/m]
    cta = css[/\.lp-dash-next \.lp-cta\s*\{[^}]+\}/m]
    progress = css[/\.lp-dash-next__progress\s*\{[^}]+\}/m]

    assert_match(/flex-wrap:\s*nowrap/, block)
    assert_match(/min-width:\s*0/, block)
    assert_match(/max-width:\s*100%/, block)
    assert_match(/width:\s*100%/, block)

    assert_match(/flex:\s*1\s+1\s+0%/, title)
    assert_match(/min-width:\s*0/, title)
    assert_match(/text-overflow:\s*ellipsis/, title)
    assert_match(/white-space:\s*nowrap/, title)

    assert_match(/flex:\s*0\s+0\s+auto/, cta)
    assert_match(/min-height:\s*2\.75rem/, cta)
    assert_match(/font-weight:\s*700/, progress)
  end

  private

  def assert_banner_state(key, tone: :steady)
    prefix = Strategy::NextAction::Copy::PREFIXES.fetch(key)
    assert_select ".lp-dash-next.is-#{tone}[data-next-action-key=#{key}][data-next-action-tone=#{tone}]", count: 1
    title = css_select(".lp-dash-next__title").text
    assert title.start_with?(prefix.strip) || title.include?(prefix.strip),
           "expected #{prefix.inspect} in #{title.inspect}"
    assert_match(/🧭|📍|⚔️|🏕️|🏁|⚠️|🔥|✨|🌑/, title)
    assert_select ".lp-dash-next__face[src*='fox']", count: 1
  end

  def clear_setup_gap!
    seed_today_habits!(@journey.commitment_habit_count)
    need = @journey.commitment_battle_count.to_i
    todos = @user.daily_todos.for_day(Date.current).ordered.to_a
    while todos.size < need
      todos << @user.daily_todos.create!(
        title: "Setup fight #{todos.size + 1}",
        scheduled_on: Date.current,
        aspect_key: "career",
        start_time: "09:00",
        end_time: "10:00",
        position: 500 + todos.size
      )
    end
    @user.daily_todos.for_day(Date.current).find_each do |todo|
      next if todo.timed?

      todo.update!(start_time: "09:00", end_time: "10:00")
    end
  end

  def seed_today_habits!(count)
    have = @user.habits.active.on_home.count
    (have + 1).upto(count) do |n|
      @user.habits.create!(
        name: "Habit #{n}", unit: "times", points: 5, frequency: "daily",
        active: true, show_on_home: true, quantity_checkin: false
      )
    end
  end

  def build_spine_without_cascade!
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan",
      title: "Get interviews", position: 0
    )
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Improve apps", position: 0
    )
  end

  def build_spine_and_cascade!(title:)
    plan = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: @goal, horizon: "plan",
      title: "Get interviews", position: 0
    )
    project = @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: plan, horizon: "project",
      title: "Improve apps", position: 0
    )
    leaf = practice_leaf_for!(project)
    @user.strategy_goals.create!(
      life_area: @area, life_journey: @journey, parent: leaf, horizon: "day",
      title: title, scheduled_on: Date.current, position: 0
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    project
  end

  def complete_all_todos!
    @user.daily_todos.for_day(Date.current).find_each do |todo|
      todo.update!(completed_at: Time.current)
    end
  end
end
