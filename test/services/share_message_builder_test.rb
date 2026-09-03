require "test_helper"

class ShareMessageBuilderTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @url = "https://lifepoints.onrender.com/"
    @previous_locale = I18n.locale
    I18n.locale = :en
  end

  teardown do
    I18n.locale = @previous_locale
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
    assert_match(/Life Climb/, message)
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

  test "builds german walking headline" do
    habit = @user.habits.create!(
      name: "Steps",
      unit: "steps",
      points: 5,
      frequency: "daily",
      stat_type: "growth",
      position: 103
    )
    habit.daily_logs.create!(logged_on: Date.current, amount: 13_000)

    I18n.with_locale(:de) do
      headline = ShareMessageBuilder.new(habit, landing_url: @url).headline
      assert_equal "🚶 Heute habe ich 13,000 steps zurückgelegt.", headline
    end
  end

  test "builds spanish reading headline" do
    habit = @user.habits.create!(
      name: "Ruby",
      unit: "pages",
      points: 5,
      frequency: "daily",
      stat_type: "growth",
      position: 104
    )
    habit.daily_logs.create!(logged_on: Date.current, amount: 20)

    I18n.with_locale(:es) do
      message = ShareMessageBuilder.new(habit, landing_url: @url).call
      assert_match(/📚 Hoy leí 20 pages de Ruby\./, message)
      assert_match(/Pruébalo:/, message)
    end
  end

  test "body excludes landing url so platforms can attach it separately" do
    habit = habits(:one)
    body = ShareMessageBuilder.new(habit, landing_url: @url).body
    refute_includes body, @url
  end
end
