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

  test "returns typed plan suggestions from injected client" do
    client = StubClient.new(
      {
        "summary" => "Several approaches could work.",
        "question" => "How are you planning to achieve this?",
        "suggestions" => [
          { "type" => "plan", "title" => "Grow my business" },
          { "type" => "obstacle", "title" => "Should be coerced to plan in phase 1" },
          "Start freelancing"
        ]
      }
    )

    result = Ai::StrategyService.call(goal: "Earn $25,000", client:)

    assert_equal "Several approaches could work.", result["summary"]
    assert_equal "How are you planning to achieve this?", result["question"]
    assert_equal [
      { "type" => "plan", "title" => "Grow my business" },
      { "type" => "plan", "title" => "Should be coerced to plan in phase 1" },
      { "type" => "plan", "title" => "Start freelancing" }
    ], result["suggestions"]
  end

  test "prefers question-only when suggestions are empty" do
    client = StubClient.new(
      {
        "summary" => "Need a bit more direction.",
        "question" => "Job, business, freelance, or unsure?",
        "suggestions" => []
      }
    )

    result = Ai::StrategyService.call(goal: "Earn $25,000", client:)
    assert_equal "Job, business, freelance, or unsure?", result["question"]
    assert_equal [], result["suggestions"]
  end

  test "maps legacy keys and includes context in the outbound prompt" do
    payload = {
      "choices" => [
        {
          "message" => {
            "content" => {
              summary: "Freelance path fits.",
              question: nil,
              suggestions: [
                { type: "plan", title: "Start freelancing on weekends" },
                { type: "plan", title: "Raise rates with current skills" }
              ]
            }.to_json
          }
        }
      ]
    }
    http = FakeHttp.new(FakeResponse.new(code: 200, body: payload.to_json))
    client = Ai::Client.new(api_key: "test-key", provider: "openrouter", http:)

    result = Ai::StrategyService.call(
      goal: "Earn $25,000 in 12 months",
      context: {
        current_reality: "I have a full-time job as a Ruby developer.",
        ideal_scene: "I want to earn the extra income from freelancing."
      },
      client:
    )

    body = JSON.parse(http.last_request.body)
    user_content = body.dig("messages", 1, "content")
    system_content = body.dig("messages", 0, "content")

    assert_match(/Goal: Earn \$25,000 in 12 months/, user_content)
    assert_match(/Current reality: I have a full-time job as a Ruby developer\./, user_content)
    assert_match(/Ideal scene: I want to earn the extra income from freelancing\./, user_content)
    assert_match(/Never create or modify user data/i, system_content)
    assert_match(/Minimum information/i, system_content)
    assert_match(/Goal → Plans → Projects → Battles/, system_content)
    assert_equal "json_object", body.dig("response_format", "type")
    assert_equal "https://openrouter.ai/api/v1/chat/completions", http.last_uri.to_s
    assert_equal "LifePoints", http.last_request["X-Title"]
    assert_equal 2, result["suggestions"].size
    assert_nil result["question"]
  end

  test "raises when goal is blank" do
    assert_raises(Ai::Error) do
      Ai::StrategyService.call(goal: "  ", client: StubClient.new({}))
    end
  end

  test "propagates timeout errors from the client" do
    client = StubClient.new(error: Ai::TimeoutError.new("timed out"))

    assert_raises(Ai::TimeoutError) do
      Ai::StrategyService.call(goal: "Earn $25,000", client:)
    end
  end

  test "client raises when api key is missing" do
    client = Ai::Client.new(api_key: "")

    error = assert_raises(Ai::ConfigurationError) do
      client.complete(system: "sys", user: "usr")
    end
    assert_match(/AI_API_KEY/, error.message)
  end

  test "client resolves groq base url from provider" do
    client = Ai::Client.new(api_key: "x", provider: "groq")
    assert_equal "https://api.groq.com/openai/v1", client.base_url
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
end
