# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Ai
  # Thin OpenAI HTTP client for one-shot structured JSON calls.
  #
  # Env:
  #   OPENAI_API_KEY        — required to call the API
  #   AI_STRATEGY_MODEL     — default gpt-5.4-mini
  #   AI_TIMEOUT_SECONDS    — default 20
  #   OPENAI_API_BASE_URL   — optional override (default https://api.openai.com/v1)
  class Client
    DEFAULT_MODEL = "gpt-5.4-mini"
    DEFAULT_TIMEOUT = 20
    DEFAULT_BASE_URL = "https://api.openai.com/v1"
    CHAT_PATH = "/chat/completions"

    STRATEGY_SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[summary questions suggested_strategies],
      properties: {
        summary: { type: "string" },
        questions: {
          type: "array",
          items: { type: "string" }
        },
        suggested_strategies: {
          type: "array",
          items: { type: "string" }
        }
      }
    }.freeze

    def initialize(
      api_key: ENV["OPENAI_API_KEY"],
      model: ENV.fetch("AI_STRATEGY_MODEL", DEFAULT_MODEL),
      timeout: ENV.fetch("AI_TIMEOUT_SECONDS", DEFAULT_TIMEOUT).to_i,
      base_url: ENV.fetch("OPENAI_API_BASE_URL", DEFAULT_BASE_URL),
      http: nil
    )
      @api_key = api_key.to_s.strip.presence
      @model = model.to_s.strip.presence || DEFAULT_MODEL
      @timeout = timeout.positive? ? timeout : DEFAULT_TIMEOUT
      @base_url = base_url.to_s.chomp("/")
      @http = http
    end

    # Completes a one-shot chat request and returns parsed JSON Hash.
    def complete(system:, user:, schema: STRATEGY_SCHEMA, schema_name: "strategy_plan")
      raise Ai::ConfigurationError, "OPENAI_API_KEY is not set" if @api_key.blank?

      body = {
        model: @model,
        temperature: 0.4,
        messages: [
          { role: "system", content: system },
          { role: "user", content: user }
        ],
        response_format: {
          type: "json_schema",
          json_schema: {
            name: schema_name,
            strict: true,
            schema: schema
          }
        }
      }

      response = post_json(CHAT_PATH, body)
      content = extract_content(response)
      parse_json(content)
    end

    private

    def post_json(path, payload)
      uri = URI.join("#{@base_url}/", path.delete_prefix("/"))
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request.body = JSON.generate(payload)

      raw = perform(uri, request)
      parse_response_body(raw)
    end

    def perform(uri, request)
      if @http
        return @http.call(uri, request)
      end

      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: @timeout,
        read_timeout: @timeout
      ) do |http|
        http.request(request)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
      raise Ai::TimeoutError, "AI request timed out after #{@timeout}s (#{e.class})"
    rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT => e
      raise Ai::ResponseError, "AI connection failed (#{e.class})"
    end

    def parse_response_body(raw)
      code = raw.code.to_i
      body = raw.body.to_s

      begin
        parsed = body.present? ? JSON.parse(body) : {}
      rescue JSON::ParserError
        raise Ai::ResponseError, "AI returned non-JSON (HTTP #{code})"
      end

      unless code.between?(200, 299)
        message = parsed.dig("error", "message").presence || "HTTP #{code}"
        raise Ai::ResponseError, "AI request failed: #{message}"
      end

      parsed
    end

    def extract_content(response)
      content = response.dig("choices", 0, "message", "content")
      raise Ai::ResponseError, "AI response missing message content" if content.blank?

      content
    end

    def parse_json(content)
      JSON.parse(content)
    rescue JSON::ParserError
      raise Ai::ResponseError, "AI returned invalid JSON content"
    end
  end
end
