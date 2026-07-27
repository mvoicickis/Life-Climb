# frozen_string_literal: true

require "test_helper"

class AiStrategyServiceTest < ActiveSupport::TestCase
  class FakeHttp
    attr_reader :last_uri, :last_request

    def initialize(response)
      @response = response
    end

    def call(uri, request)
      @last_uri = uri
      @last_request = request
      @response
    end
  end

  class FakeResponse
    attr_reader :code, :body

    def initialize(code:, body:)
      @code = code.to_s
      @body = body
    end
  end

  class StubClient
    def initialize(payload = nil, error: nil)
      @payload = payload
      @error = error
    end

    def complete(**)
      raise @error if @error

      @payload
    end
  end

  test "returns structured strategy suggestions from injected client" do
    client = StubClient.new(
      {
        "summary" => "Focus on a clear savings path.",
        "questions" => [ "What is your monthly surplus?", "" ],
        "suggested_strategies" => [ "Automate transfers", "Cut one recurring cost" ]
      }
    )

    result = Ai::StrategyService.call(goal: "Save $25k", client:)

    assert_equal "Focus on a clear savings path.", result["summary"]
    assert_equal [ "What is your monthly surplus?" ], result["questions"]
    assert_equal [ "Automate transfers", "Cut one recurring cost" ], result["suggested_strategies"]
  end

  test "includes optional context in the user prompt via live client path" do
    payload = {
      "choices" => [
        {
          "message" => {
            "content" => {
              summary: "Clarify the mountain.",
              questions: [ "Why this goal?" ],
              suggested_strategies: [ "Define a milestone" ]
            }.to_json
          }
        }
      ]
    }
    http = FakeHttp.new(FakeResponse.new(code: 200, body: payload.to_json))
    client = Ai::Client.new(api_key: "test-key", model: "gpt-5.4-mini", http:)

    result = Ai::StrategyService.call(
      goal: "Save $25k",
      context: { ideal_scene: "Freedom", current_reality: "Debt", life_area: "Money" },
      client:
    )

    body = JSON.parse(http.last_request.body)
    user_content = body.dig("messages", 1, "content")
    assert_match(/Goal: Save \$25k/, user_content)
    assert_match(/Ideal scene: Freedom/, user_content)
    assert_match(/Current reality: Debt/, user_content)
    assert_match(/Life area: Money/, user_content)
    assert_equal "Clarify the mountain.", result["summary"]
    assert_equal "json_schema", body.dig("response_format", "type")
    assert_equal "strategy_plan", body.dig("response_format", "json_schema", "name")
  end

  test "raises when goal is blank" do
    assert_raises(Ai::Error) do
      Ai::StrategyService.call(goal: "  ", client: StubClient.new({}))
    end
  end

  test "propagates timeout errors from the client" do
    client = StubClient.new(error: Ai::TimeoutError.new("timed out"))

    assert_raises(Ai::TimeoutError) do
      Ai::StrategyService.call(goal: "Save $25k", client:)
    end
  end

  test "client raises when api key is missing" do
    client = Ai::Client.new(api_key: nil)

    error = assert_raises(Ai::ConfigurationError) do
      client.complete(system: "sys", user: "usr")
    end
    assert_match(/OPENAI_API_KEY/, error.message)
  end

  test "client raises response error on non-success http status" do
    http = FakeHttp.new(
      FakeResponse.new(code: 401, body: { error: { message: "Invalid API key" } }.to_json)
    )
    client = Ai::Client.new(api_key: "bad", http:)

    error = assert_raises(Ai::ResponseError) do
      client.complete(system: "sys", user: "usr")
    end
    assert_match(/Invalid API key/, error.message)
  end

  test "normalizes non-hash payloads as response errors" do
    client = StubClient.new([ "not", "a", "hash" ])

    assert_raises(Ai::ResponseError) do
      Ai::StrategyService.call(goal: "Save $25k", client:)
    end
  end
end
