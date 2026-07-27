# frozen_string_literal: true

require "test_helper"

class AdminBootstrapTest < ActiveSupport::TestCase
  setup do
    @email = "owner-bootstrap@example.com"
    User.where(email_address: @email).delete_all
    @prev = {
      "ADMIN_EMAIL" => ENV["ADMIN_EMAIL"],
      "ADMIN_PASSWORD" => ENV["ADMIN_PASSWORD"],
      "ADMIN_BOOTSTRAP_PASSWORD" => ENV["ADMIN_BOOTSTRAP_PASSWORD"]
    }
  end

  teardown do
    @prev.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  test "creates and promotes admin when env is set" do
    ENV["ADMIN_EMAIL"] = @email
    ENV["ADMIN_PASSWORD"] = "password12345"
    ENV.delete("ADMIN_BOOTSTRAP_PASSWORD")

    result = Admin::Bootstrap.ensure!
    assert result[:ok], result.inspect

    user = User.find_by!(email_address: @email)
    assert user.admin?
    assert User.authenticate_by(email_address: @email, password: "password12345")
  end

  test "promotes existing user without requiring password" do
    user = User.create!(
      email_address: @email,
      name: "Owner",
      password: "password12345",
      password_confirmation: "password12345",
      home_stat_count: 6,
      onboarding_completed_at: Time.current,
      admin: false
    )

    ENV["ADMIN_EMAIL"] = @email
    ENV.delete("ADMIN_PASSWORD")
    ENV.delete("ADMIN_BOOTSTRAP_PASSWORD")

    result = Admin::Bootstrap.ensure!
    assert result[:ok], result.inspect
    assert user.reload.admin?
  end

  test "login promotes configured admin email" do
    user = User.create!(
      email_address: @email,
      name: "Owner",
      password: "password12345",
      password_confirmation: "password12345",
      home_stat_count: 6,
      onboarding_completed_at: Time.current,
      support_milestones_shown: [ "adventure_guide" ],
      admin: false
    )

    ENV["ADMIN_EMAIL"] = @email

    post session_path, params: { email_address: @email, password: "password12345" }
    assert_response :redirect
    assert user.reload.admin?
  end
end
