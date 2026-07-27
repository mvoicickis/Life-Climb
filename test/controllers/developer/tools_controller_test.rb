# frozen_string_literal: true

require "test_helper"

class DeveloperToolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(
      planning_version: 2,
      onboarding_completed_at: Time.current,
      support_milestones_shown: [ "adventure_guide" ],
      developer: false
    )
    sign_in_as @user
  end

  test "non-developer cannot see developer tools on settings" do
    get settings_path
    assert_response :success
    assert_no_match(/Developer Tools/, response.body)
    assert_no_match(/Restart New Player Experience/, response.body)
  end

  test "developer sees restart new player experience on settings" do
    @user.update_columns(developer: true)
    get settings_path
    assert_response :success
    assert_match(/Developer Tools/, response.body)
    assert_match(/Restart New Player Experience/, response.body)
  end

  test "non-developer restart endpoint returns 403" do
    seed_strategy!
    goal_ids = @user.strategy_goals.pluck(:id)

    post restart_new_player_experience_developer_tools_path
    assert_response :forbidden

    @user.reload
    assert @user.onboarding_completed?
    assert_equal goal_ids.sort, @user.strategy_goals.pluck(:id).sort
  end

  test "developer restart wipes strategy data and redirects to onboarding welcome" do
    @user.update_columns(developer: true)
    seed_strategy!

    post restart_new_player_experience_developer_tools_path
    assert_redirected_to v2_onboarding_path(step: "welcome")

    @user.reload
    assert_nil @user.onboarding_completed_at
    refute @user.adventure_guide_done?
    assert_equal 0, @user.strategy_goals.count
    assert_equal 0, @user.life_journeys.count
  end

  test "env whitelist promotes and allows restart" do
    @user.update_columns(developer: false)
    ENV["DEVELOPER_EMAIL"] = @user.email_address

    begin
      post restart_new_player_experience_developer_tools_path
      assert_redirected_to v2_onboarding_path(step: "welcome")
      assert @user.reload.read_attribute(:developer)
    ensure
      ENV.delete("DEVELOPER_EMAIL")
    end
  end

  private

  def seed_strategy!
    Onboarding::Run.call(
      user: @user,
      area_key: "learning",
      title: "Learn German",
      ideal_scene: "Fluent",
      current_reality: "Beginner",
      today_mission: "Learn 20 words",
      closer_percent: 10,
      route_mission: true
    )
    @user.update!(support_milestones_shown: [ "adventure_guide" ])
  end
end
