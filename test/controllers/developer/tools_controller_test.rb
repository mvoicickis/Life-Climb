# frozen_string_literal: true

require "test_helper"

class DeveloperToolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(
      planning_version: 2,
      onboarding_completed_at: Time.current,
      support_milestones_shown: [ "adventure_guide" ]
    )
    sign_in_as @user
  end

  test "non-developer cannot see developer tools on settings" do
    @user.update_columns(developer: false)
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
    @user.update_columns(developer: false)
    goal_ids = @user.strategy_goals.pluck(:id)

    post restart_new_player_experience_developer_tools_path
    assert_response :forbidden

    @user.reload
    assert @user.onboarding_completed?
    assert_equal goal_ids, @user.strategy_goals.pluck(:id)
  end

  test "developer restart clears flags and redirects to onboarding welcome" do
    @user.update_columns(developer: true)
    existing_goals = @user.strategy_goals.count
    existing_journeys = @user.life_journeys.count

    post restart_new_player_experience_developer_tools_path
    assert_redirected_to v2_onboarding_path(step: "welcome")

    @user.reload
    assert_nil @user.onboarding_completed_at
    refute @user.adventure_guide_done?
    assert_equal existing_goals, @user.strategy_goals.count
    assert_equal existing_journeys, @user.life_journeys.count
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
end
