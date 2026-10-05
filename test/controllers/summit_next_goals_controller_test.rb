# frozen_string_literal: true

require "test_helper"

class SummitNextGoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Goals::Current.clear_cache!
    @user = User.create!(
      name: "Summit flow",
      email_address: "summit-flow-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      planning_version: 2,
      onboarding_completed_at: Time.current
    )
    sign_in_as @user
    @bootstrap = Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Summit goal",
      camp_titles: [ "Only camp" ]
    )
    @journey = @bootstrap.journey
    finish_camp!(@bootstrap.projects.first)
  end

  test "show goal step at summit" do
    get summit_next_goal_path
    assert_response :success
    assert_select "h1", text: I18n.t("summit_next_goal.mountain_name_title")
  end

  test "camps json create redirects to new mountain" do
    patch summit_next_goal_path(step: "goal"),
          params: { onboarding: { goal: "Next peak" } }
    assert_redirected_to summit_next_goal_path(step: "camps")

    patch summit_next_goal_path(step: "camps"),
          params: { onboarding: { camp_titles: [ "Step one" ] } },
          headers: { Accept: "application/json" }

    assert_response :success
    body = JSON.parse(response.body)
    new_journey = @user.life_journeys.active.order(:id).last
    assert_equal life_journey_path(new_journey), body["redirect_to"]
    assert_equal "completed", @journey.reload.status
  end

  test "discards draft when journey id mismatches" do
    get summit_next_goal_path
    session[:summit_next_goal] = {
      "goal" => "Stale",
      "camp_titles" => [ "Old camp" ],
      "life_journey_id" => 9_999_999
    }

    get summit_next_goal_path(step: "camps")
    assert_nil session[:summit_next_goal], "stale draft should be cleared from session"
    assert_redirected_to summit_next_goal_path(step: "goal")

    follow_redirect!
    assert_response :success
    assert_select "input#summit_onboarding_goal" do |inputs|
      assert inputs.first["value"].to_s.blank?, "goal field should be empty after discard"
    end
    refute_match(/Old camp/, response.body)
    refute_match(/Stale/, response.body)
  end

  private

  def finish_camp!(camp)
    camp.children.for_kind("day").find_each { |b| b.update!(completed_at: Time.current) }
    camp.complete!
  end
end
