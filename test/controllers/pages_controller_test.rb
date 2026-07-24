require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "landing page is public" do
    get root_path
    assert_response :success
    assert_match(/Grow a little/, response.body)
    assert_match(/Start free/, response.body)
  end

  test "signed in users go to dashboard from root" do
    sign_in_as users(:one)
    get root_path
    assert_redirected_to dashboard_path
  end
end
