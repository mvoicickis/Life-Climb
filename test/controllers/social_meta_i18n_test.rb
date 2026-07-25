require "test_helper"

class SocialMetaI18nTest < ActionDispatch::IntegrationTest
  test "english landing includes localized open graph tags" do
    get root_path
    assert_response :success
    assert_match(/property="og:locale" content="en_US"/, response.body)
    assert_match(/property="og:title" content="LifePoints — Become better than yesterday"/, response.body)
    assert_match(/Build better habits, earn points/, response.body)
    assert_match(%r{og-lifepoints-en\.png}, response.body)
    assert_match(/name="twitter:card" content="summary_large_image"/, response.body)
    assert_match(/hreflang="de"/, response.body)
    assert_match(/hreflang="lv"/, response.body)
    assert_match(/hreflang="x-default"/, response.body)
  end

  test "latvian landing switches og image and copy" do
    patch locale_path(locale: :lv)
    follow_redirect!

    get root_path
    assert_response :success
    assert_match(/property="og:locale" content="lv_LV"/, response.body)
    assert_match(/Kļūsti labāks nekā vakar/, response.body)
    assert_match(/Veido labākus ieradumus, pelni punktus/, response.body)
    assert_match(%r{og-lifepoints-lv\.png}, response.body)
  end

  test "german landing switches og image and copy" do
    patch locale_path(locale: :de)
    follow_redirect!

    get root_path
    assert_response :success
    assert_match(/property="og:locale" content="de_DE"/, response.body)
    assert_match(/Werde jeden Tag ein bisschen besser/, response.body)
    assert_match(/Baue Gewohnheiten auf, sammle Punkte/, response.body)
    assert_match(%r{og-lifepoints-de\.png}, response.body)
  end

  test "locale query param localizes social preview for crawlers" do
    get root_path(locale: :de)
    assert_response :success
    assert_match(/property="og:locale" content="de_DE"/, response.body)
    assert_match(%r{og-lifepoints-de\.png}, response.body)
  end
end
