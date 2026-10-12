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

  test "terms serves English template" do
    get terms_path
    assert_response :success
    assert_match(/Last updated: 12 October 2026/, response.body)
    assert_match(/The app/, response.body)
    assert_match(/German law applies/, response.body)
    assert_match(/href="#{privacy_path}"/, response.body)
    assert_match(/href="#{delete_account_path}"/, response.body)
    assert_match(/mailto:mvoicickis@gmail.com/, response.body)
    assert_no_match(/TODO \(Mareks\)/, response.body)
  end

  test "privacy serves English template" do
    get privacy_path
    assert_response :success
    assert_match(/What we collect/, response.body)
    assert_match(/keeping you logged in and showing the app offline/, response.body)
    assert_match(/Last updated: 11 October 2026/, response.body)
    assert_match(/General Data Protection Regulation/, response.body)
    assert_no_match(/TODO \(Mareks\)/, response.body)
  end

  test "delete account page describes in-app deletion and limits" do
    get delete_account_path
    assert_response :success
    assert_match(/You/, response.body)
    assert_match(/password/i, response.body)
    assert_match(/subscription/i, response.body)
    assert_match(/Anonymous usage events/i, response.body)
    assert_match(/Stripe/i, response.body)
    assert_match(/Can't log in\?/, response.body)
    assert_match(/mailto:mvoicickis@gmail.com/, response.body)
  end

  test "impressum shows German and English provider details" do
    get impressum_path
    assert_response :success
    assert_match(/Impressum \/ Legal notice/, response.body)
    assert_match(/Angaben gemäß § 5 DDG/, response.body)
    assert_match(/Information according to § 5 DDG/, response.body)
    assert_match(/57392 Schmallenberg/, response.body)
    assert_match(/Deutschland/, response.body)
    assert_match(/Germany/, response.body)
    assert_match(/mailto:mvoicickis@gmail.com/, response.body)
    assert_match(/tel:\+353872346580/, response.body)
    assert_no_match(/TODO \(Mareks\)/, response.body)
  end
end
