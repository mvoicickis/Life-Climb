# frozen_string_literal: true

require "test_helper"

module Notifications
  class MorningNudgeCopyTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.daily_todos.delete_all
      @user.life_journeys.delete_all
      @user.strategy_goals.delete_all
    end

    test "uses goal title without mountain prefix" do
      seed_climb!(@user, title: "Get my driving license", today_mission: "Warm up")
      date = Date.new(2026, 8, 4) # Tuesday

      copy = MorningNudgeCopy.for(user: @user, date: date, locale: :en)

      assert_equal "Get my driving license", copy.title
      assert_equal "You wanted this. Go get it.", copy.body
    end

    test "truncates long goal title at forty graphemes" do
      long_title = "Build a sustainable side business that earns on its own"
      seed_climb!(@user, title: long_title, today_mission: "Step one")
      date = Date.new(2026, 8, 4)

      copy = MorningNudgeCopy.for(user: @user, date: date, locale: :en)

      assert copy.title.end_with?("…")
      assert_operator copy.title.each_grapheme_cluster.count, :<=, 41
    end

    test "latvian goal title is preserved" do
      seed_climb!(@user, title: "Iemācīties vācu valodu līdz B1", today_mission: "Vocabulary")
      date = Date.new(2026, 8, 4)

      copy = MorningNudgeCopy.for(user: @user, date: date, locale: :en)

      assert_equal "Iemācīties vācu valodu līdz B1", copy.title
    end

    test "no journey uses plan title and weekday body" do
      date = Date.new(2026, 8, 6) # Thursday

      copy = MorningNudgeCopy.for(user: @user, date: date, locale: :en)

      assert_equal "Plan today", copy.title
      assert_equal "Big goals fall to small steps. Take one.", copy.body
    end

    test "weekday body follows date not server default" do
      seed_climb!(@user, title: "Get my driving license")
      berlin_tuesday = Date.new(2026, 8, 4)

      copy = MorningNudgeCopy.for(user: @user, date: berlin_tuesday, locale: :en)

      assert_equal "You wanted this. Go get it.", copy.body
    end

    test "body uses linked battle todo" do
      seed_climb!(@user, title: "Get my driving license", today_mission: "Warm up")
      date = Date.new(2026, 8, 6)
      battle = @user.strategy_goals.where(horizon: "day").order(:id).last
      @user.daily_todos.delete_all
      @user.daily_todos.create!(
        title: "Call my mum",
        aspect_key: "career",
        scheduled_on: date,
        position: 0,
        lp_reward: 10,
        strategy_goal_id: battle.id,
        tag: "strategy"
      )

      copy = MorningNudgeCopy.for(user: @user, date: date, locale: :en)

      assert_equal "Today: Call my mum", copy.body
    end

    test "body ignores ad-hoc todo without strategy goal" do
      seed_climb!(@user, title: "Get my driving license")
      date = Date.new(2026, 8, 3) # Monday
      @user.daily_todos.create!(
        title: "Secret battle name",
        aspect_key: "career",
        scheduled_on: date,
        position: 0,
        lp_reward: 10
      )

      copy = MorningNudgeCopy.for(user: @user, date: date, locale: :en)

      assert_equal "New week. Make it count.", copy.body
      refute_includes copy.body, "Secret battle"
    end

    test "copy builder does not create records" do
      seed_climb!(@user, title: "Get my driving license")
      date = Date.new(2026, 8, 6)
      todo_count = DailyTodo.count
      goal_count = StrategyGoal.count

      MorningNudgeCopy.for(user: @user, date: date, locale: :en)

      assert_equal todo_count, DailyTodo.count
      assert_equal goal_count, StrategyGoal.count
    end
  end
end
