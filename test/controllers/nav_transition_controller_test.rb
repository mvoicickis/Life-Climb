# frozen_string_literal: true

require "test_helper"

class NavTransitionControllerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    @journey = seed_climb!(@user)
  end

  test "Today and Mountain expose real nav hrefs and opt into view transitions" do
    get dashboard_path
    assert_response :success
    assert_select 'meta[name="view-transition"][content="same-origin"]'
    assert_select "a.lp-dash-nav__link[href=?]", dashboard_path
    assert_select "a.lp-dash-nav__link[href=?]", life_journey_path(@journey)

    get life_journey_path(@journey)
    assert_response :success
    assert_select 'meta[name="view-transition"][content="same-origin"]'
    assert_select "a.lp-dash-nav__link[href=?]", dashboard_path
  end

  test "You does not opt into view transitions" do
    get settings_path
    assert_response :success
    assert_select 'meta[name="view-transition"]', count: 0
  end
end
