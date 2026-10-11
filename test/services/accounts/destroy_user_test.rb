# frozen_string_literal: true

require "test_helper"

module Accounts
  class DestroyUserTest < ActiveSupport::TestCase
    setup do
      @target = User.create!(
        name: "Delete Me",
        email_address: "destroy-user-#{SecureRandom.hex(4)}@example.com",
        password: "password12345",
        password_confirmation: "password12345",
        onboarding_completed_at: Time.current,
        character: "fox"
      )
    end

    test "destroys user with bootstrap tree holding second goal logs and todos" do
      allow_extra_climbs!(@target)
      result = Onboarding::Bootstrap.call(
        user: @target,
        goal_title: "Primary destination",
        camp_titles: [ "Camp alpha", "Camp beta" ]
      )
      journey = result.journey
      area = journey.life_area
      primary_goal = result.goal
      camp = result.projects.first
      battle = result.first_battle

      Strategy::HoldingProject.ensure!(user: @target, journey: journey)

      second_goal = @target.strategy_goals.create!(
        life_area: area,
        life_journey: journey,
        horizon: "goal",
        title: "Second destination",
        position: 1,
        due_on: Strategy::YearCycle.default_goal_due
      )
      second_plan = second_goal.children.create!(
        user: @target,
        life_area: area,
        life_journey: journey,
        horizon: "plan",
        title: "Side path",
        position: 0
      )
      second_camp = second_plan.children.create!(
        user: @target,
        life_area: area,
        life_journey: journey,
        horizon: "project",
        title: "Side camp",
        position: 0,
        target_amount: 50,
        unit: "pages",
        quantity_kind: "up",
        current_amount: 0
      )
      side_battle = second_camp.children.create!(
        user: @target,
        life_area: area,
        life_journey: journey,
        horizon: "day",
        title: "Read today",
        scheduled_on: Date.current,
        position: 0
      )

      battle.update!(completed_at: Time.current)
      side_battle.update!(completed_at: Time.current)

      todo = @target.daily_todos.find_by(strategy_goal_id: battle.id) ||
             @target.daily_todos.create!(
               title: battle.title,
               aspect_key: "purpose",
               scheduled_on: Date.current,
               strategy_goal: battle,
               position: 0,
               completed_at: Time.current
             )

      @target.strategy_quantity_logs.create!(
        strategy_goal: second_camp,
        source_day: side_battle,
        daily_todo: todo,
        amount: 8,
        unit: "pages",
        logged_on: Date.current
      )

      goal_ids = @target.strategy_goals.pluck(:id)
      assert goal_ids.size >= 8

      destroy_result = DestroyUser.call(user: @target)

      assert destroy_result.ok?
      assert_not User.exists?(@target.id)
      goal_ids.each { |id| assert_not StrategyGoal.exists?(id) }
      assert_equal 0, StrategyQuantityLog.where(user_id: @target.id).count
      assert_equal 0, DailyTodo.where(user_id: @target.id).count
    end

    test "stripe failure leaves user intact" do
      @target.update_columns(stripe_subscription_id: "sub_fail", subscription_status: "active")

      with_singleton_stubs(
        Stripe::Subscription => {
          cancel: ->(*) { raise Stripe::APIError.new("network down") }
        }
      ) do
        result = DestroyUser.call(user: @target)
        assert_not result.ok?
        assert_equal :stripe, result.reason
      end

      assert User.exists?(@target.id)
    end
  end
end
