# frozen_string_literal: true

require "test_helper"

class PushOffersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(
      push_offer_dismiss_count: 0,
      push_offer_dismissed_at: nil,
      push_offer_permission_denied_at: nil,
      push_offer_show_days: 0
    )
    sign_in_as @user
    seed_climb!(@user, today_mission: "Ship auth")
  end

  test "destroy marks soft dismiss and shown" do
    travel_to Time.zone.local(2026, 8, 6, 15, 0, 0) do
      assert_difference -> { @user.reload.push_offer_dismiss_count }, 1 do
        delete push_offer_path
        assert_response :no_content
      end
      @user.reload
      assert @user.push_offer_dismissed_at.present?
      assert_equal Date.new(2026, 8, 6), @user.push_offer_last_shown_on
    end
  end

  test "update marks permission denied and shown" do
    travel_to Time.zone.local(2026, 8, 6, 15, 0, 0) do
      patch push_offer_path
      assert_response :no_content
      @user.reload
      assert @user.push_offer_permission_denied_at.present?
      assert_equal Date.new(2026, 8, 6), @user.push_offer_last_shown_on
    end
  end

  test "shown records local day" do
    travel_to Time.zone.local(2026, 8, 6, 15, 0, 0) do
      patch shown_push_offer_path
      assert_response :no_content
      @user.reload
      assert_equal Date.new(2026, 8, 6), @user.push_offer_last_shown_on
      assert_equal 1, @user.push_offer_show_days
    end
  end

  test "shown with count_show_day false skips show days" do
    travel_to Time.zone.local(2026, 8, 6, 15, 0, 0) do
      patch shown_push_offer_path, params: { count_show_day: false }
      assert_response :no_content
      @user.reload
      assert_equal Date.new(2026, 8, 6), @user.push_offer_last_shown_on
      assert_equal 0, @user.push_offer_show_days
    end
  end

  test "shown does not double increment show days same day" do
    travel_to Time.zone.local(2026, 8, 6, 15, 0, 0) do
      patch shown_push_offer_path
      assert_response :no_content
      patch shown_push_offer_path
      assert_response :no_content
      assert_equal 1, @user.reload.push_offer_show_days
    end
  end

  test "requires authentication" do
    sign_out
    delete push_offer_path
    assert_redirected_to new_session_path
  end
end
