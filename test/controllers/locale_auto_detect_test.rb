# frozen_string_literal: true

require "test_helper"

class LocaleAutoDetectTest < ActionDispatch::IntegrationTest
  teardown { I18n.locale = I18n.default_locale }

  test "Accept-Language picks a supported locale for a first-time visitor" do
    get root_path, headers: { "Accept-Language" => "lv-LV,lv;q=0.9,en;q=0.8" }

    assert_response :success
    assert_select "html[lang=?]", "lv"
    assert_match(/Viens kalns\. Šodienas kauja/, response.body)
    assert_match(/Sākt bez maksas/, response.body)
  end

  test "Accept-Language falls back to English for an unsupported language" do
    get root_path, headers: { "Accept-Language" => "fr-FR,fr;q=0.9,it;q=0.8" }

    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_match(/One mountain\. Today’s battle/, response.body)
    assert_match(/Start free/, response.body)
  end

  test "session locale wins over Accept-Language" do
    patch locale_path(locale: :de)
    follow_redirect!

    get root_path, headers: { "Accept-Language" => "lv-LV,lv;q=0.9" }

    assert_response :success
    assert_select "html[lang=?]", "de"
    assert_match(/Ein Berg\. Die Schlacht von heute/, response.body)
  end

  test "Latvian Accept-Language carries through signup to Welcome with picker" do
    get root_path, headers: { "Accept-Language" => "lv,en;q=0.8" }
    assert_select "html[lang=?]", "lv"

    post registration_url, params: {
      user: {
        name: "Mareks",
        email_address: "lv-browser@example.com",
        password: "password12345",
        password_confirmation: "password12345"
      }
    }, headers: { "Accept-Language" => "lv,en;q=0.8" }
    assert_redirected_to v2_onboarding_path

    follow_redirect!
    assert_response :success
    assert_select "html[lang=?]", "lv"
    assert_match(/Laipni lūgts LifePoints/, response.body)
    assert_select ".lp-adventure__lang .landing-lang-btn", minimum: 5
    assert_select ".lp-adventure__lang .landing-lang-btn.is-active", text: "LV"
  end
end
