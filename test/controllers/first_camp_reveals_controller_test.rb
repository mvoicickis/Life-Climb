# frozen_string_literal: true

require "test_helper"

class FirstCampRevealsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "first-camp-dismiss-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )
    sign_in_as @user
    @result = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Ship it",
      camp_titles: [ "First camp" ]
    )
    @journey = @result.journey
    @project = @result.projects.first
    @seed = @result.first_battle
  end

  test "update clears reveal flag and keeps seed battle" do
    assert @journey.first_camp_reveal_pending?

    patch life_journey_first_camp_reveal_path(@journey), as: :turbo_stream

    assert_response :success
    @journey.reload
    refute @journey.first_camp_reveal_pending?
    assert_equal @seed.id, @project.reload.children.for_kind("day").sole.id
    assert @user.daily_todos.for_day(Date.current).exists?(strategy_goal_id: @seed.id)
  end
end
