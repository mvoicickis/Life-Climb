# frozen_string_literal: true

require "test_helper"

class Strategy::Quantity::LogTest < ActiveSupport::TestCase
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @area = life_areas(:one_self)
    @goal = @user.strategy_goals.create!(life_area: @area, horizon: "goal", title: "G", position: 0)
    @plan = @user.strategy_goals.create!(
      life_area: @area, parent: @goal, horizon: "plan", title: "P", position: 0
    )
    @project = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Read book",
      position: 0, target_amount: 700, unit: "pages"
    )
    @leaf = practice_leaf_for!(@project)
    @day = @user.strategy_goals.create!(
      life_area: @area, parent: @leaf, horizon: "day", title: "Read chapter",
      scheduled_on: Date.current, position: 0
    )
  end

  test "logs amount toward path-level project and updates current_amount" do
    entry = Strategy::Quantity::Log.call(
      project: @project, amount: 7, user: @user, source_day: @day, logged_on: Date.current
    )

    assert entry.persisted?
    assert_equal BigDecimal("7"), @project.reload.current_amount
    assert_equal "pages", entry.unit
    assert_equal 1, Strategy::Progress.percent(@project)
    assert_not @project.completed?
  end

  test "generic units work for pages currency and activity counts" do
    pages = Strategy::Quantity::Log.call(project: @project, amount: 10, user: @user)
    assert_equal "pages", pages.unit

    income = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Income",
      position: 1, target_amount: 10_000, unit: "€"
    )
    Strategy::Quantity::Log.call(project: income, amount: 250.5, user: @user)
    assert_equal BigDecimal("250.5"), income.reload.current_amount
    assert_equal 3, Strategy::Progress.percent(income) # 250.5/10000 → 3%

    emails = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Outreach",
      position: 2, target_amount: 200, unit: "emails"
    )
    Strategy::Quantity::Log.call(project: emails, amount: 5, user: @user)
    assert_equal BigDecimal("5"), emails.reload.current_amount
    assert_equal 3, Strategy::Progress.percent(emails) # 5/200 → 3%
  end

  test "reaching target auto-completes project and syncs ancestors" do
    Strategy::Quantity::Log.call(project: @project, amount: 700, user: @user)

    assert @project.reload.completed?
    assert_equal 100, Strategy::Progress.percent(@project)
    assert @plan.reload.completed?
    assert @goal.reload.completed?
  end

  test "progress follows amount/target on the quantified path camp" do
    assert_equal 0, Strategy::Progress.percent(@project)
    Strategy::Quantity::Log.call(project: @project, amount: 350, user: @user)

    assert_equal 50, Strategy::Progress.percent(@project.reload)
  end

  test "rejects non-quantified project" do
    plain = @user.strategy_goals.create!(
      life_area: @area, parent: @plan, horizon: "project", title: "Plain", position: 3
    )

    assert_raises(ArgumentError) do
      Strategy::Quantity::Log.call(project: plain, amount: 1, user: @user)
    end
  end
end
