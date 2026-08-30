# frozen_string_literal: true

require "test_helper"

class Today::BattlefieldPromptTest < ActiveSupport::TestCase
  test "returns nil when health is not all clear" do
    health = Today::BattlefieldHealth.call(open_count: 1, total_count: 2)

    assert_nil Today::BattlefieldPrompt.call(health: health)
  end

  test "returns nil when health is empty" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 0)

    assert_nil Today::BattlefieldPrompt.call(health: health)
  end

  test "day_won when all clear with no coaching context" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 3)

    result = Today::BattlefieldPrompt.call(health: health)

    assert_equal :day_won, result.prompt_key
    assert_equal 3, result.won_count
    assert_includes result.headline, "3"
    assert_equal I18n.t("dash.battlefield.win_state.day_won.sub"), result.sub
  end

  test "project check is passed through but does not change prompt key" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 1)
    project = Struct.new(:title).new("Ship docs")

    result = Today::BattlefieldPrompt.call(
      health: health,
      project_check: project,
      battles_waiting_count: 2,
      upcoming_battle: { title: "Later", scheduled_on: Date.current + 1.day }
    )

    assert_equal :battles_waiting, result.prompt_key
    assert_equal project, result.project_check
  end

  test "battles_waiting when extra battles remain on mountain" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 1)

    result = Today::BattlefieldPrompt.call(
      health: health,
      battles_waiting_count: 2
    )

    assert_equal :battles_waiting, result.prompt_key
    assert_equal 2, result.battles_waiting_count
    assert_includes result.headline, "2"
  end

  test "upcoming when a future battle is scheduled" do
    health = Today::BattlefieldHealth.call(open_count: 0, total_count: 1)
    upcoming = { title: "Tomorrow fight", scheduled_on: Date.current + 1.day }

    result = Today::BattlefieldPrompt.call(
      health: health,
      upcoming_battle: upcoming
    )

    assert_equal :upcoming, result.prompt_key
    assert_equal upcoming, result.upcoming_battle
    assert_includes result.headline, "Tomorrow fight"
    assert_includes result.sub, I18n.l(upcoming[:scheduled_on], format: :short)
  end
end
