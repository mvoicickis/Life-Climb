# frozen_string_literal: true

require "test_helper"

class Patterns::Detectors::CompletionRateTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @aspect = "self"
  end

  test "returns nil below scheduled and days_active floors" do
    5.times do |i|
      create_todo!(scheduled_on: Date.current - i, completed: true)
    end

    assert_nil Patterns::Detectors::CompletionRate.call(user: @user)
  end

  test "twelve todos on one date yield days_active 1 and no finding" do
    12.times do |i|
      create_todo!(scheduled_on: Date.current, completed: i.even?, title: "Same day #{i}")
    end

    summary = Patterns::BattleStats.summary(@user)
    assert_equal 1, summary[:days_active]
    assert_equal 12, summary[:scheduled]
    assert_nil Patterns::Detectors::CompletionRate.call(user: @user)
  end

  test "rate uses scheduled_on even when completed next calendar day" do
    seed_active_days!(completed_flags: Array.new(10, true))
    monday = Date.current.beginning_of_week(:monday) - 7
    todo = create_todo!(scheduled_on: monday, completed: false, title: "Monday plan")
    todo.update!(completed_at: (monday + 1).beginning_of_day + 1.hour)

    finding = Patterns::Detectors::CompletionRate.call(user: @user)
    assert_not_nil finding
    assert_equal :completion_rate_30d, finding.key
    assert_operator finding.data[:completed], :>=, 1
  end

  test "high band uses mountain CTA at 65 percent" do
    # 13 completed of 20 across 10 days => 65%
    seed_spread!(total: 20, completed: 13, days: 10)

    finding = Patterns::Detectors::CompletionRate.call(user: @user)
    assert_equal :high, finding.cta_variant
    assert_equal 65, finding.data[:rate]
    assert_match(/Open Mountain/i, finding.action_label)
  end

  test "neutral band at mid rates with Today CTA and no advice" do
    seed_spread!(total: 20, completed: 10, days: 10) # 50%

    finding = Patterns::Detectors::CompletionRate.call(user: @user)
    assert_equal :neutral, finding.cta_variant
    assert_equal 50, finding.data[:rate]
    assert_match(/Open Today/i, finding.action_label)
    refute_match(/lighter|Shrink|fewer/i, finding.observation)
  end

  test "low band below 40 percent" do
    seed_spread!(total: 20, completed: 6, days: 10) # 30%

    finding = Patterns::Detectors::CompletionRate.call(user: @user)
    assert_equal :low, finding.cta_variant
    assert_equal 30, finding.data[:rate]
    assert_match(/lighter Today plan/i, finding.observation)
    assert_match(/Open Today/i, finding.action_label)
  end

  private

  def create_todo!(scheduled_on:, completed:, title: "Battle")
    @user.daily_todos.create!(
      title: title,
      aspect_key: @aspect,
      scheduled_on: scheduled_on,
      completed_at: completed ? scheduled_on.to_time.change(hour: 12) : nil,
      position: @user.daily_todos.where(scheduled_on: scheduled_on).count
    )
  end

  def seed_active_days!(completed_flags:)
    completed_flags.each_with_index do |done, i|
      create_todo!(scheduled_on: Date.current - i, completed: done, title: "Day #{i}")
    end
  end

  def seed_spread!(total:, completed:, days:)
    per_day, rem = total.divmod(days)
    done_left = completed
    days.times do |i|
      count = per_day + (i < rem ? 1 : 0)
      count.times do |j|
        do_complete = done_left.positive?
        done_left -= 1 if do_complete
        create_todo!(
          scheduled_on: Date.current - i,
          completed: do_complete,
          title: "D#{i}-#{j}"
        )
      end
    end
  end
end
