require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "registration requires name and greets with it on dashboard after onboarding shortcut" do
    assert_difference -> { UserEvent.named("signup_started").count }, 1 do
      get new_registration_url
    end
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
    assert_redirected_to v2_onboarding_path(step: "goal")
  end

  test "registration captures browser time zone into notification preference" do
    assert_difference("User.count", 1) do
      assert_difference("NotificationPreference.count", 1) do
        post registration_url, params: {
          time_zone: "Europe/Berlin",
          user: {
            name: "Berlin User",
            email_address: "berlin-new@example.com",
            password: "password12345",
            password_confirmation: "password12345"
          }
        }
      end
    end

    user = User.find_by!(email_address: "berlin-new@example.com")
    assert_equal "Europe/Berlin", user.notification_preference.time_zone
  end

  test "registration ignores invalid time zone" do
    assert_difference("User.count", 1) do
      assert_no_difference("NotificationPreference.count") do
        post registration_url, params: {
          time_zone: "Not/AZone",
          user: {
            name: "No Zone",
            email_address: "nozone@example.com",
            password: "password12345",
            password_confirmation: "password12345"
          }
        }
      end
    end
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
