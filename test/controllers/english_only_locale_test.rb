# frozen_string_literal: true

require "test_helper"

class EnglishOnlyLocaleTest < ActionDispatch::IntegrationTest
  teardown { I18n.locale = I18n.default_locale }

  test "Accept-Language lv still renders English landing" do
    get root_path, headers: { "HTTP_ACCEPT_LANGUAGE" => "lv-LV,lv;q=0.9,en;q=0.8" }
    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_select "h1.lp-landing-hero__title", text: "The mountain is yours to climb"
    assert_match(/Start free/, response.body)
  end
end
