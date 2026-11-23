# frozen_string_literal: true

require "test_helper"

class V2OnboardingBattlesCopyTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Alex",
      email_address: "battles-copy-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      character: "fox"
    )
    Onboarding::Bootstrap.call(
      user: @user,
      goal_title: "Edit my book",
      camp_titles: [ "Finish draft" ],
      complete_onboarding: false,
      first_camp_reveal_status: "done"
    )
    @user.primary_focused_journey.mark_onboarding_v3_climb_done!
    sign_in_as @user
  end

  test "battles step shows Karen copy with example collapsed and no raw interpolation" do
    get v2_onboarding_path(step: "battles")
    assert_response :success

    assert_select "h1", text: I18n.t("v2_onboarding.battles_title")
    assert_includes response.body, I18n.t("v2_onboarding.battles_lead")
    assert_includes response.body, I18n.t("v2_onboarding.battles_today_kicker")
    assert_select "#onboarding_battle_add[placeholder=?]", I18n.t("v2_onboarding.battles_add_placeholder")
    assert_select "details.lp-ob-battles__example summary", text: I18n.t("v2_onboarding.battles_example_toggle")
    assert_select ".lp-ob-steps__add-btn", count: 1
    refute_includes response.body, "What is one thing you can finish today?"
    refute_includes response.body, "%{goal}"
  end
end
