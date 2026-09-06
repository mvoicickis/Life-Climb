# frozen_string_literal: true

require "test_helper"

class FirstCampBattlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "first-camp-#{SecureRandom.hex(4)}@example.com",
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

  test "create replaces seed battle with custom battle" do
    assert @journey.first_camp_reveal_pending?

    assert_equal 1, @project.reload.children.for_kind("day").count

    post life_journey_first_camp_battles_path(@journey),
           params: { title: "Write the README", repeat: "none" },
           as: :turbo_stream

    assert_response :success
    @journey.reload
    @project.reload
    refute @journey.first_camp_reveal_pending?

    battle = @project.children.for_kind("day").sole
    assert_equal "Write the README", battle.title
    assert_equal "none", battle.repeat
    refute_equal @seed.id, battle.id
    assert @user.daily_todos.for_day(Date.current).exists?(strategy_goal_id: battle.id)
  end

  test "create accepts weekly repeat with weekdays" do
    post life_journey_first_camp_battles_path(@journey),
         params: {
           title: "Practice guitar",
           repeat: "weekly",
           repeat_weekdays: [ 1, 3, 5 ]
         },
         as: :turbo_stream

    assert_response :success
    battle = @project.reload.children.for_kind("day").sole
    assert battle.repeat_weekly?
    assert_equal [ 1, 3, 5 ], battle.repeat_weekdays_array
  end
end
