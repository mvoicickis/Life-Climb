# frozen_string_literal: true

require "test_helper"

class AreasControllerTest < ActionDispatch::IntegrationTest
  include ClimbTestHelper

  setup do
    @user = users(:one)
    sign_in_as @user
    seed_climb!(@user, area_key: "money", title: "Financial freedom", today_mission: "Track spending")
  end

  test "index redirects to habits areas anchor" do
    get areas_path
    assert_redirected_to habits_path(anchor: "areas")
  end

  test "create adds area for current user" do
    assert_difference -> { @user.areas.count }, 1 do
      post areas_path, params: { area: { name: "Health" } }
    end
    assert_redirected_to habits_path(anchor: "areas")
    assert_equal "Health", @user.areas.ordered.last.name
  end

  test "destroy removes area scoped to current user" do
    area = @user.areas.create!(name: "Finance")
    assert_difference -> { @user.areas.count }, -1 do
      delete area_path(area)
    end
    assert_redirected_to habits_path(anchor: "areas")
  end

  test "cannot destroy another users area" do
    other = users(:two).areas.create!(name: "Secret")
    assert_no_difference -> { Area.count } do
      delete area_path(other)
    end
    assert_response :not_found
  end
end
