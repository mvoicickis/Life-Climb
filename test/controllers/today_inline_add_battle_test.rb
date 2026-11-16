# frozen_string_literal: true

require "test_helper"

class TodayInlineAddBattleTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user, today_mission: "Ship auth")
    dismiss_onboarding_missions!(@user)
    @camp = Strategy::PathProject.resolve(user: @user, journey: @journey)
    assert @camp.present?
  end

  test "create adds a day battle in the current camp and streams it onto Today" do
    before_total = @camp.children.for_kind("day").count
    before_todos = @user.daily_todos.for_day(Date.current).count

    assert_difference -> { @user.strategy_goals.where(horizon: "day").count }, 1 do
      post today_battles_path,
           params: { title: "  Call the bank  " },
           as: :turbo_stream
    end
    assert_response :ok

    battle = @user.strategy_goals.where(horizon: "day", title: "Call the bank").order(:id).last
    assert_equal @camp.id, battle.parent_id
    assert_equal Date.current, battle.scheduled_on
    assert_equal "none", battle.repeat
    assert_equal @journey.id, battle.life_journey_id

    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: battle.id)
    assert_equal "Call the bank", todo.title
    assert_equal before_todos + 1, @user.daily_todos.for_day(Date.current).count
    assert_equal before_total + 1, @camp.children.for_kind("day").count

    assert_includes response.body, "today-battlefield-body"
    assert_includes response.body, "today-battlefield-count"
    assert_includes response.body, "today-battlefield-header"
    assert_includes response.body, "today-battlefield-add-host"
    assert_match(/Call the bank/, response.body)
    assert_match(/#{Regexp.escape(@camp.title)}/, response.body)
  end

  test "blank title is rejected" do
    assert_no_difference -> { @user.strategy_goals.where(horizon: "day").count } do
      post today_battles_path, params: { title: "   " }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
  end

  test "another users camp is never used" do
    other = users(:two)
    other_journey = other.primary_focused_journey || seed_climb!(other, today_mission: "Other fight")
    other_camp = Strategy::PathProject.resolve(user: other, journey: other_journey)
    other_before = other.strategy_goals.where(horizon: "day").count

    post today_battles_path, params: { title: "My fight only" }, as: :turbo_stream
    assert_response :ok

    battle = @user.strategy_goals.where(horizon: "day", title: "My fight only").order(:id).last
    assert_equal @user.id, battle.user_id
    assert_not_equal other_camp&.id, battle.parent_id
    assert_equal other_before, other.strategy_goals.where(horizon: "day").count
  end

  test "no open camp uses the holding camp" do
    @user.strategy_goals.where(horizon: "project", life_journey_id: @journey.id).find_each do |camp|
      camp.update_columns(completed_at: Time.current)
    end
    assert_nil Strategy::PathProject.resolve(user: @user, journey: @journey.reload)

    post today_battles_path, params: { title: "Holding fight" }, as: :turbo_stream
    assert_response :ok

    battle = @user.strategy_goals.where(horizon: "day", title: "Holding fight").order(:id).last
    assert battle.parent.holding?
    assert_equal @user.id, battle.user_id
    assert @user.daily_todos.for_day(Date.current).exists?(strategy_goal_id: battle.id)
  end

  test "counts and camp total update in the stream" do
    camp_before = Today::CampProgress.call(
      user: @user, journey: @journey, goal: Goals::Current.goal_for(user: @user, journey: @journey)
    )
    assert camp_before.present?

    post today_battles_path, params: { title: "Grow the bar" }, as: :turbo_stream
    assert_response :ok

    assert_includes response.body, "today-battlefield-count"
    assert_includes response.body, "today-battlefield-header"
    assert_match(/width: /, response.body)

    camp_after = Today::CampProgress.call(
      user: @user, journey: @journey, goal: Goals::Current.goal_for(user: @user, journey: @journey)
    )
    assert_equal camp_before[:total] + 1, camp_after[:total]
  end

  test "page shows inline add and hides mountain link when reveal is done" do
    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-add-host .lp-today-add-battle", count: 1
    assert_select "#today-battlefield-add-host [data-controller~='today-add-battle']", count: 1
    assert_select "a.lp-today-v2-mountain-link.is-add-on-mountain", count: 0
  end

  test "first camp reveal keeps the mountain empty cta and hides inline add" do
    user = User.create!(
      name: "Reveal add",
      email_address: "reveal-add-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current
    )
    sign_in_as user

    bootstrap = Onboarding::Bootstrap.call(
      user: user,
      goal_title: "Reveal climb",
      camp_titles: [ "First" ]
    )
    journey = bootstrap.journey
    dismiss_onboarding_missions!(user)
    user.daily_todos.for_day(Date.current).destroy_all
    user.strategy_goals.where(horizon: "day", scheduled_on: Date.current).destroy_all
    assert journey.first_camp_reveal_pending?

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-add-host .lp-today-add-battle", count: 0
    assert_select "#today-battlefield-body a.lp-today-empty-cta__pill", count: 1
  end

  test "all clear shows inline add instead of add another battle pill" do
    Strategy::CascadeToDaily.call(user: @user, life_area: @journey.life_area)
    @user.daily_todos.for_day(Date.current).find_each do |todo|
      todo.update!(completed_at: Time.current)
    end

    get dashboard_path
    assert_response :success

    assert_select "#today-battlefield-add-host .lp-today-add-battle.is-all-clear", count: 1
    assert_select "#today-battlefield-end-day-host .lp-today-empty-cta__pill", count: 0
    assert_select ".lp-today-all-clear", count: 1
  end

  test "day full returns an error and does not leave a silent battle" do
    Strategy::CascadeToDaily.call(user: @user, life_area: @journey.life_area)
    while GameRules.daily_open_count(@user, Date.current) < GameRules::MAX_DAILY_TODOS
      n = GameRules.daily_open_count(@user, Date.current)
      @camp.children.create!(
        user: @user,
        life_area: @journey.life_area,
        life_journey: @journey,
        horizon: "day",
        title: "Fill #{n}",
        scheduled_on: Date.current,
        position: n + 10
      )
      Strategy::CascadeToDaily.sync_goal!(
        user: @user,
        goal: @camp.children.for_kind("day").order(:id).last
      )
    end
    assert GameRules.daily_open_cap_reached?(@user, Date.current)
    day_before = @user.strategy_goals.where(horizon: "day").count

    post today_battles_path, params: { title: "One too many" }, as: :turbo_stream
    assert_response :unprocessable_entity
    assert_equal day_before, @user.strategy_goals.where(horizon: "day").count
    assert_nil @user.strategy_goals.find_by(horizon: "day", title: "One too many")
  end
end
