require "test_helper"

class LifeAreaSelectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show renders catalog" do
    get life_area_selections_url
    assert_response :success
    assert_match(/Career/, response.body)
    assert_match(/Purpose/, response.body)
  end

  test "update selects areas" do
    patch life_area_selections_url, params: { keys: %w[self learning] }
    assert_redirected_to life_area_selections_url

    @user.reload
    assert @user.planning_v2?
    assert_equal %w[self learning], @user.life_areas.v2_selected.pluck(:key)
  end
end
