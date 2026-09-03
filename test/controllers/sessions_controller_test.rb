require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new" do
    get new_session_path
    assert_response :success
    assert_match(/Back to Home|Atpakaļ uz sākumu/, response.body)
    assert_match(/Lifeclimb/, response.body)
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password12345" }

    assert_redirected_to dashboard_url
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(users(:one))

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "admin signs in to admin dashboard" do
    admin = users(:admin)
    post session_path, params: { email_address: admin.email_address, password: "password12345" }
    assert_redirected_to admin_root_url
  end
end
