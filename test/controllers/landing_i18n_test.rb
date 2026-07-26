require "test_helper"

class LandingI18nTest < ActionDispatch::IntegrationTest
  test "landing page is available in english by default" do
    get root_path
    assert_response :success
    assert_match(/One mountain\. Today’s battle/, response.body)
    assert_match(/Start free/, response.body)
  end

  test "landing page switches to latvian" do
    patch locale_path(locale: :lv)
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Viens kalns\. Šodienas kauja/, response.body)
    assert_match(/Sākt bez maksas/, response.body)
  end

  test "landing page switches to german" do
    patch locale_path(locale: :de)
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Ein Berg\. Die Schlacht von heute/, response.body)
    assert_match(/Kostenlos starten/, response.body)
  end

  test "landing page switches to spanish" do
    patch locale_path(locale: :es)
    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Una montaña\. La batalla de hoy/, response.body)
    assert_match(/Empezar gratis/, response.body)
  end
end
