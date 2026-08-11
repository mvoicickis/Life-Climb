# frozen_string_literal: true

require "test_helper"

class Patterns::DetectorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @aspect = "self"
  end

  test "returns empty array when history is below floors" do
    assert_equal [], Patterns::Detector.call(user: @user)
    assert_equal 1, @user.pattern_snapshots.where(computed_on: Date.current).count
    assert_equal [], @user.pattern_snapshots.find_by!(computed_on: Date.current).findings
  end

  test "stores data hashes without rendered observation strings" do
    seed_enough_history!

    findings = Patterns::Detector.call(user: @user)
    assert findings.any?

    row = @user.pattern_snapshots.find_by!(computed_on: Date.current)
    stored = row.findings.first
    assert stored.key?("key")
    assert stored.key?("data")
    assert stored.key?("cta_variant")
    refute stored.key?("observation")
    assert stored["data"].key?("rate") || stored["data"].key?("worst_wday")
  end

  test "two calls on the same day create one snapshot and skip re-running detectors" do
    seed_enough_history!
    first = Patterns::Detector.call(user: @user)
    assert first.any?

    @user.daily_todos.delete_all

    second = Patterns::Detector.call(user: @user)
    assert_equal 1, @user.pattern_snapshots.where(computed_on: Date.current).count
    assert_equal first.map(&:key), second.map(&:key)
    assert_equal first.map { |f| f.data }, second.map { |f| f.data }
  end

  test "observations render at read time via I18n" do
    seed_enough_history!
    Patterns::Detector.call(user: @user)

    finding = Patterns::Detector.call(user: @user).find { |f| f.key == :completion_rate_30d }
    assert_not_nil finding
    assert_match(/%/, finding.observation)
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

  def seed_enough_history!
    # 10 days, 2 todos/day, 70% done → completion rate finding
    10.times do |i|
      day = Date.current - i
      create_todo!(scheduled_on: day, completed: true, title: "a #{i}")
      create_todo!(scheduled_on: day, completed: i < 4, title: "b #{i}")
    end
  end
end
