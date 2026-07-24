require "test_helper"

class ShareMessageBuilderTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @url = "https://lifepoints.onrender.com/"
  end

  test "builds reading style headline from pages unit" do
    habit = @user.habits.create!(
      name: "Ruby",
      unit: "pages",
      points: 5,
      frequency: "daily",
      stat_type: "growth",
      position: 99
    )
    habit.daily_logs.create!(logged_on: Date.current, amount: 20)

    message = ShareMessageBuilder.new(habit, landing_url: @url).call

    assert_match(/📚 Today I read 20 pages of Ruby\./, message)
    assert_match(/LifePoints/, message)
    assert_includes message, @url
  end

  test "builds walking headline with delimited steps" do
    habit = @user.habits.create!(
      name: "Steps",
      unit: "steps",
      points: 5,
      frequency: "daily",
      stat_type: "growth",
      position: 100
    )
    habit.daily_logs.create!(logged_on: Date.current, amount: 13_000)

    headline = ShareMessageBuilder.new(habit, landing_url: @url).headline
    assert_equal "🚶 Today I walked 13,000 steps.", headline
  end

  test "builds push-up headline" do
    habit = @user.habits.create!(
      name: "Push-ups",
      unit: "reps",
      points: 5,
      frequency: "daily",
      stat_type: "growth",
      position: 101
    )
    habit.daily_logs.create!(logged_on: Date.current, amount: 50)

    headline = ShareMessageBuilder.new(habit, landing_url: @url).headline
    assert_equal "💪 Today I completed 50 reps.", headline
  end

  test "builds language study headline" do
    habit = @user.habits.create!(
      name: "German",
      unit: "minutes",
      points: 5,
      frequency: "daily",
      stat_type: "growth",
      position: 102
    )
    habit.daily_logs.create!(logged_on: Date.current, amount: 45)

    headline = ShareMessageBuilder.new(habit, landing_url: @url).headline
    assert_equal "🇩🇪 Today I studied German for 45 minutes.", headline
  end

  test "body excludes landing url so platforms can attach it separately" do
    habit = habits(:one)
    body = ShareMessageBuilder.new(habit, landing_url: @url).body
    refute_includes body, @url
  end
end
