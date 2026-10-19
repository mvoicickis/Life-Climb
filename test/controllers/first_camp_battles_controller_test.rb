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
  end

  test "create saves first custom battle" do
    assert @journey.first_camp_reveal_pending?

    assert_equal 0, @project.reload.children.for_kind("day").count

    post life_journey_first_camp_battles_path(@journey),
           params: { title: "Write the README", repeat: "none" },
           as: :turbo_stream

    assert_response :success
    @journey.reload
    @project.reload
    refute @journey.first_camp_reveal_pending?
    assert @journey.first_camp_win_nudge_pending?

    battle = @project.children.for_kind("day").sole
    assert_equal "Write the README", battle.title
    assert_equal "none", battle.repeat
    assert @user.daily_todos.for_day(Date.current).exists?(strategy_goal_id: battle.id)
  end

  test "create via form submit clears reveal and saves battle" do
    get life_journey_path(@journey)

    assert_response :success
    assert_select "form.lp-first-camp-setup__form input[type=submit]"

    post life_journey_first_camp_battles_path(@journey),
         params: { title: "Study for 20 minutes", repeat: "none" },
         as: :turbo_stream

    assert_response :success
    refute @journey.reload.first_camp_reveal_pending?
    assert_equal "Study for 20 minutes", @project.reload.children.for_kind("day").sole.title
  end

  test "create rejects blank title with message" do
    post life_journey_first_camp_battles_path(@journey),
         params: { title: "   ", repeat: "none" },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_match(/Write one small thing first\./, response.body)
    assert @journey.reload.first_camp_reveal_pending?
  end

  test "create when reveal is not pending returns visit stream and creates nothing" do
    add_todays_battle!(user: @user, project: @project, journey: @journey)
    @journey.clear_first_camp_reveal!

    assert_equal 1, @project.reload.children.for_kind("day").count

    post life_journey_first_camp_battles_path(@journey),
         params: { title: "Should not save", repeat: "none" },
         as: :turbo_stream

    assert_response :unprocessable_entity
    assert_match(/turbo_visit/, response.body)
    assert_match life_journey_path(@journey), response.body
    assert_equal 1, @project.reload.children.for_kind("day").count
    refute_equal "Should not save", @project.children.for_kind("day").sole.title
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
