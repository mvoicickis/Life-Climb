# frozen_string_literal: true

require "test_helper"

class InstallOffersControllerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    @user.update!(
      character: "fox",
      support_milestones_shown: [ User::ADVENTURE_GUIDE_KEY ],
      install_offer_dismiss_count: 0,
      install_offer_dismissed_at: nil,
      install_offer_installed_at: nil
    )
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
  end

  test "destroy marks dismissed" do
    assert_difference -> { @user.reload.install_offer_dismiss_count }, 1 do
      delete install_offer_path
      assert_response :no_content
    end
    assert @user.reload.install_offer_dismissed_at.present?
  end

  test "update marks installed without changing dismiss_count" do
    @user.update!(install_offer_dismiss_count: 1, install_offer_dismissed_at: 1.day.ago)

    assert_no_difference -> { @user.reload.install_offer_dismiss_count } do
      patch install_offer_path
      assert_response :no_content
    end
    assert @user.reload.install_offer_installed_at.present?
  end

  test "requires authentication" do
    sign_out
    delete install_offer_path
    assert_redirected_to new_session_path
  end
end
