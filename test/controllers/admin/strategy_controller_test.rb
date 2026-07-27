# frozen_string_literal: true

require "test_helper"

class AdminStrategyControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
  end

  test "non admin cannot open ai strategist" do
    sign_in_as @user
    get admin_strategy_path
    assert_redirected_to dashboard_path
  end

  test "admin can open ai strategist form" do
    sign_in_as @admin
    get admin_strategy_path
    assert_response :success
    assert_match(/Ask strategist/i, response.body)
  end

  test "admin can run strategist with stubbed service" do
    sign_in_as @admin

    fake = {
      "summary" => "Freelance path fits.",
      "question" => "How many hours per week?",
      "suggestions" => [ { "type" => "plan", "title" => "Start freelancing" } ]
    }

    singleton = Ai::StrategyService.singleton_class
    singleton.alias_method :__original_call, :call
    singleton.define_method(:call) { |**_kwargs| fake }

    begin
      post admin_strategy_path, params: {
        goal: "Earn $25,000 in 12 months",
        current_reality: "Full-time Ruby developer",
        ideal_scene: "Freelance income"
      }
    ensure
      singleton.alias_method :call, :__original_call
      singleton.remove_method :__original_call
    end

    assert_response :success
    assert_match(/Freelance path fits/, response.body)
    assert_match(/How many hours per week/, response.body)
    assert_match(/Start freelancing/, response.body)
    assert_match(/Not saved/, response.body)
  end

  test "blank goal is rejected" do
    sign_in_as @admin
    post admin_strategy_path, params: { goal: "  " }
    assert_response :unprocessable_entity
    assert_match(/Goal is required/i, response.body)
  end
end
