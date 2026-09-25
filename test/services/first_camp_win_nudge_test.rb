# frozen_string_literal: true

require "test_helper"

class FirstCampWinNudgeTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "nudge-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship it",
      camp_titles: [ "First camp" ]
    )
    @journey = @result.journey
    @project = @result.projects.first
    @journey.set_first_camp_win_nudge!
    @battle = @project.children.for_kind("day").sole
  end

  test "clear_after_battle_win clears nudge for pinned camp battle" do
    assert @journey.first_camp_win_nudge_pending?

    FirstCampWinNudge.clear_after_battle_win!(user: @user, battle: @battle)

    refute @journey.reload.first_camp_win_nudge_pending?
  end

  test "clear_after_battle_win ignores other camps" do
    other_project = @user.strategy_goals.create!(
      life_area: @project.life_area,
      life_journey: @journey,
      parent: @project.parent,
      horizon: "project",
      title: "Other",
      position: 1
    )
    other_battle = other_project.children.create!(
      user: @user,
      life_area: @project.life_area,
      life_journey: @journey,
      horizon: "day",
      title: "Elsewhere",
      scheduled_on: Date.current,
      position: 0
    )

    FirstCampWinNudge.clear_after_battle_win!(user: @user, battle: other_battle)

    assert @journey.reload.first_camp_win_nudge_pending?
  end
end
