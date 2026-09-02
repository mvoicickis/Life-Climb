# frozen_string_literal: true

require "test_helper"

class PushOffersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_permission_denied_at: nil
    )
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
  end

  test "destroy marks soft dismiss" do
    assert_difference -> { @user.reload.push_offer_dismiss_count }, 1 do
      delete push_offer_path
      assert_response :no_content
    end
    assert @user.reload.push_offer_dismissed_at.present?
  end

  test "update marks permission denied" do
    patch push_offer_path
    assert_response :no_content
    assert @user.reload.push_offer_permission_denied_at.present?
  end

  test "requires authentication" do
    sign_out
    delete push_offer_path
    assert_redirected_to new_session_path
  end
end
