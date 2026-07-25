require "test_helper"

class LandingI18nTest < ActionDispatch::IntegrationTest
  test "landing page is available in english by default" do
    get root_path
    assert_response :success
    assert_match(/Become a better version of yourself every day/, response.body)
    assert_match(/Start free/, response.body)
  end

  test "landing page switches to latvian" do
    patch locale_path(locale: :lv)
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Kļūsti par labāku sevi katru dienu/, response.body)
    assert_match(/Sākt bez maksas/, response.body)
  end
end
