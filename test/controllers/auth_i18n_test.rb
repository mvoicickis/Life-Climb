require "test_helper"

class AuthI18nTest < ActionDispatch::IntegrationTest
  test "registration page translates to latvian" do
    patch locale_path(locale: :lv)
    follow_redirect!

    get new_registration_path
    assert_response :success
    assert_match(/Izveidot kontu/, response.body)
    assert_match(/Sāc skaitīt to, kas ir svarīgi/, response.body)
    assert_match(/E-pasts/, response.body)
    assert_match(/Parole/, response.body)
  end

  test "sign in page translates to latvian" do
    patch locale_path(locale: :lv)
    follow_redirect!

    get new_session_path
    assert_response :success
    assert_match(/Laipni lūgts atpakaļ/, response.body)
    assert_match(/Ienākt/, response.body)
  end
end
