require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "registration requires name and greets with it on dashboard after onboarding shortcut" do
    get new_registration_url
    assert_response :success
    assert_select "input[name='user[name]']"

    assert_difference("User.count", 1) do
      post registration_url, params: {
        user: {
          name: "Mareks",
          email_address: "mareks-new@example.com",
          password: "password12345",
          password_confirmation: "password12345"
        }
      }
    end

    user = User.find_by!(email_address: "mareks-new@example.com")
    assert_equal "Mareks", user.name
    assert_equal "Mareks", user.display_name
    assert_redirected_to v2_onboarding_path
  end

  test "registration without name fails" do
    assert_no_difference("User.count") do
      post registration_url, params: {
        user: {
          email_address: "noname@example.com",
          password: "password12345",
          password_confirmation: "password12345"
        }
      }
    end
    assert_response :unprocessable_entity
  end
end
