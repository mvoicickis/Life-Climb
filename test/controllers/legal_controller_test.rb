# frozen_string_literal: true

require "test_helper"

class LegalControllerTest < ActionDispatch::IntegrationTest
  LEGAL_PATHS = {
    privacy: :privacy_path,
    terms: :terms_path,
    delete_account: :delete_account_path,
    impressum: :impressum_path
  }.freeze

  LEGAL_PATHS.each do |name, path_helper|
    test "#{name} is public when logged out" do
      get send(path_helper)
      assert_response :success
    end

    test "#{name} is reachable when logged in" do
      sign_in_as users(:one)
      get send(path_helper)
      assert_response :success
    end
  end

  test "privacy serves English template when locale is lv" do
    patch locale_path(locale: :lv)
    follow_redirect!

    get privacy_path
    assert_response :success
    assert_match(/What we collect/, response.body)
    assert_match(/TODO \(Mareks\)/, response.body)
  end

  test "delete account page describes in-app deletion and limits" do
    get delete_account_path
    assert_response :success
    assert_match(/You/, response.body)
    assert_match(/password/i, response.body)
    assert_match(/subscription/i, response.body)
    assert_match(/Anonymous usage events/i, response.body)
    assert_match(/Stripe/i, response.body)
  end

  test "impressum shows German and English sections" do
    get impressum_path
    assert_response :success
    assert_match(/Impressum \/ Legal notice/, response.body)
    assert_match(/Deutsch/, response.body)
    assert_match(/English/, response.body)
    assert_match(/TODO \(Mareks\)/, response.body)
  end
end
