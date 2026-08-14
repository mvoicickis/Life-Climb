# frozen_string_literal: true

require "test_helper"

class ObjectiveQuantityOptInTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, today_mission: "Write tests")
    @area = @user.primary_focused_journey.life_area
    @journey = @user.primary_focused_journey
    @goal = @user.strategy_goals.for_kind("goal").roots.first
    @plan = @goal.children.find(&:plan?)
    @section = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Read Atomic Habits",
      position: @plan.children.maximum(:position).to_i + 1,
      target_amount: 700, unit: "pages", current_amount: 10
    )
    @folder = @section
    @host = Strategy::EnsureFolderQuest.call(folder: @folder)
    assert @section.quantified?
    assert_equal @section, @host.quantified_path_project
  end

  test "quantified ancestor shows track toggle; non-quantified does not" do
    plain = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Plain camp",
      position: @plan.children.maximum(:position).to_i + 1
    )
    Strategy::EnsureFolderQuest.call(folder: plain)

    get objectives_strategy_goal_path(@folder)
    assert_response :success
    assert_select ".lp-climb-path__quest-title", text: /Read Atomic Habits/
    assert_select ".lp-climb-path__quest-add-track", text: /Track progress \(pages\)/i
    assert_select "#qs-add-track-#{@folder.id}"

    get objectives_strategy_goal_path(plain)
    assert_response :success
    assert_select ".lp-climb-path__quest-title", text: /Plain camp/
    assert_select ".lp-climb-path__quest-add-track", count: 0
    assert_select "#qs-add-track-#{plain.id}", count: 0
  end

  test "opted-in objective under quantified project shows amount dialog and logs" do
    tracked = @host.practice_tasks.create!(
      user: @user, title: "Read chapter 3", position: 0, track_quantity: true
    )
    plain = @host.practice_tasks.create!(
      user: @user, title: "Review notes", position: 1, track_quantity: false
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    get dashboard_path
    assert_response :success
    assert_select ".lp-dash-quest-next__row[data-controller='quantity-complete'] form[action=?]",
                  practice_task_path(tracked)
    assert_select "dialog.lp-dash-quest-sheet .lp-dash-checklist__obj[data-controller='quantity-complete'] form[action=?]",
                  practice_task_path(tracked)
    assert_select "#qty-obj-#{tracked.id}"
    assert_select "#qty-next-#{tracked.id}"
    assert_select "dialog.lp-dash-quest-sheet .lp-dash-checklist__obj[data-controller='quantity-complete'] form[action=?]",
                  practice_task_path(plain),
                  count: 0

    assert_difference -> { StrategyQuantityLog.count }, 1 do
      patch practice_task_path(tracked), params: { completed: "1", amount: "12" }
    end
    assert_redirected_to dashboard_path
    assert tracked.reload.completed?
    assert_equal BigDecimal("22"), @section.reload.current_amount
    log = StrategyQuantityLog.find_by!(practice_task_id: tracked.id)
    assert_equal BigDecimal("12"), log.amount
    assert_equal @section.id, log.strategy_goal_id
    assert_equal @host.id, log.source_day_id
  end

  test "non-opted-in objective under quantified project stays plain checkbox" do
    plain = @host.practice_tasks.create!(
      user: @user, title: "Review notes", position: 0, track_quantity: false
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    assert_no_difference -> { StrategyQuantityLog.count } do
      patch practice_task_path(plain), params: { completed: "1" }
    end
    assert plain.reload.completed?
    assert_equal BigDecimal("10"), @section.reload.current_amount
  end

  test "last objective mixed opted-in and plain finishes day once without duplicate log" do
    tracked = @host.practice_tasks.create!(
      user: @user, title: "Read chapter 3", position: 0, track_quantity: true
    )
    plain = @host.practice_tasks.create!(
      user: @user, title: "Review notes", position: 1, track_quantity: false
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)
    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @host.id)

    patch practice_task_path(tracked), params: { completed: "1", amount: "15" }
    assert_equal 1, StrategyQuantityLog.where(practice_task_id: tracked.id).count
    assert_not todo.reload.completed?

    assert_no_difference -> { StrategyQuantityLog.count } do
      assert_difference -> { @user.reload.life_points }, GameRules::BATTLE_TODO_LP do
        patch practice_task_path(plain), params: { completed: "1" }
      end
    end
    assert todo.reload.completed?
    assert @host.reload.completed?
    assert_equal true, flash[:battle_celebrate]
    assert_equal BigDecimal("25"), @section.reload.current_amount
  end

  test "undo reverses the specific objective log via practice_task_id" do
    first = @host.practice_tasks.create!(
      user: @user, title: "Read chapter 3", position: 0, track_quantity: true
    )
    second = @host.practice_tasks.create!(
      user: @user, title: "Read chapter 4", position: 1, track_quantity: true
    )
    Strategy::CascadeToDaily.call(user: @user, life_area: @area)

    patch practice_task_path(first), params: { completed: "1", amount: "10" }
    patch practice_task_path(second), params: { completed: "1", amount: "20" }
    assert_equal BigDecimal("40"), @section.reload.current_amount
    todo = @user.daily_todos.for_day(Date.current).find_by!(strategy_goal_id: @host.id)
    assert todo.completed?

    patch practice_task_path(second), params: { completed: "0" }
    assert_nil StrategyQuantityLog.find_by(practice_task_id: second.id)
    assert StrategyQuantityLog.find_by(practice_task_id: first.id)
    assert_equal BigDecimal("20"), @section.reload.current_amount
    assert_not todo.reload.completed?
    assert first.reload.completed?
    assert_not second.reload.completed?
  end

  test "creating with track_quantity under quantified ancestor persists flag" do
    post strategy_goal_practice_tasks_path(@host),
         params: { title: "Do a lesson", track_quantity: "1" }
    task = @host.practice_tasks.find_by!(title: "Do a lesson")
    assert task.track_quantity?
  end

  test "creating with track_quantity under non-quantified ancestor is ignored" do
    plain = @plan.children.create!(
      user: @user, life_area: @area, life_journey: @journey,
      horizon: "project", title: "Plain camp",
      position: @plan.children.maximum(:position).to_i + 1
    )
    host = Strategy::EnsureFolderQuest.call(folder: plain)

    post strategy_goal_practice_tasks_path(host),
         params: { title: "Do a lesson", track_quantity: "1" }
    task = host.practice_tasks.find_by!(title: "Do a lesson")
    assert_not task.track_quantity?
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password12345" }
  end
end
