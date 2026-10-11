# frozen_string_literal: true

require "test_helper"

class SelfHostedNunitoTest < ActionDispatch::IntegrationTest
  FONT_PATHS = %w[
    /fonts/nunito-v1-latin-normal.woff2
    /fonts/nunito-v1-latin-italic.woff2
    /fonts/nunito-v1-latin-ext-normal.woff2
    /fonts/nunito-v1-latin-ext-italic.woff2
    /fonts/nunito-v1-cyrillic-normal.woff2
    /fonts/nunito-v1-cyrillic-italic.woff2
  ].freeze

  test "pages do not reference Google Fonts" do
    get root_path
    assert_no_google_fonts_in_body

    sign_in_as users(:one)
    get settings_path
    assert_no_google_fonts_in_body

    sign_in_as users(:admin)
    get admin_root_path
    assert_no_google_fonts_in_body

    get "/offline.html"
    assert_no_google_fonts_in_body
  end

  test "layouts link self-hosted nunito stylesheet" do
    get root_path
    assert_match %r{/fonts/nunito\.css}, response.body

    sign_in_as users(:one)
    get settings_path
    assert_match %r{/fonts/nunito\.css}, response.body
  end

  test "font stylesheet and woff2 files are served" do
    get "/fonts/nunito.css"
    assert_response :success
    assert_equal "text/css", response.media_type

    FONT_PATHS.each do |path|
      get path
      assert_response :success, "expected 200 for #{path}"
    end
  end

  private

  def assert_no_google_fonts_in_body
    refute_match(/fonts\.googleapis\.com/, response.body)
    refute_match(/fonts\.gstatic\.com/, response.body)
  end
end
