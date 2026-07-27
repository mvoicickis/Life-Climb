# frozen_string_literal: true

require "test_helper"

class StrategyHelpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(planning_version: 2, onboarding_completed_at: Time.current)
    sign_in_as @user
  end

  test "returns strategist panel for authenticated user" do
    fake = {
      "summary" => "Freelance fits.",
      "question" => "How many hours?",
      "suggestions" => [ { "type" => "plan", "title" => "Weekend freelance" } ]
    }

    singleton = Ai::StrategyService.singleton_class
    singleton.alias_method :__original_call, :call
    singleton.define_method(:call) { |**_kwargs| fake }

    begin
      post strategy_help_path,
           params: { goal: "Earn $25k", accept_as: "fill", horizon: "plan", target_input: "#next-up-title" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    ensure
      singleton.alias_method :call, :__original_call
      singleton.remove_method :__original_call
    end

    assert_response :success
    assert_match(/Freelance fits/, response.body)
    assert_match(/Weekend freelance/, response.body)
    assert_match(/Use this/, response.body)
  end

  test "passes horizon through to the strategist service" do
    captured = {}
    fake = {
      "summary" => "Project ideas.",
      "question" => nil,
      "suggestions" => [ { "type" => "project", "title" => "Ship portfolio" } ]
    }

    singleton = Ai::StrategyService.singleton_class
    singleton.alias_method :__original_call, :call
    singleton.define_method(:call) do |**kwargs|
      captured.replace(kwargs)
      fake
    end

    begin
      post strategy_help_path,
           params: {
             goal: "Become a Rails developer",
             horizon: "project",
             plan_title: "Get interviews",
             accept_as: "fill",
             target_input: "#strategy-add-project-title",
             panel_id: "strategist-panel-add-project"
           },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    ensure
      singleton.alias_method :call, :__original_call
      singleton.remove_method :__original_call
    end

    assert_response :success
    assert_equal "project", captured[:horizon]
    assert_equal "Get interviews", captured.dig(:context, :plan_title)
    assert_match(/strategist-panel-add-project/, response.body)
    assert_match(/Ship portfolio/, response.body)
  end

  test "blank goal is rejected" do
    post strategy_help_path, params: { goal: " " }, as: :turbo_stream
    assert_response :success
    assert_match(/goal title first|Goal is required|Add your goal/i, response.body)
  end
end
