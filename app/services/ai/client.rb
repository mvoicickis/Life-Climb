# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Ai
  # OpenAI-compatible HTTP adapter. Provider is selected via env so the rest of
  # the app never depends on a specific vendor.
  #
  # Env:
  #   AI_PROVIDER         — openrouter (default) | openai | groq | gemini
  #   AI_BASE_URL         — optional override
  #   AI_API_KEY          — required (fallbacks: OPENROUTER_API_KEY, OPENAI_API_KEY)
  #   AI_STRATEGY_MODEL   — default depends on provider
  #   AI_TIMEOUT_SECONDS  — default 20
  #   AI_SITE_URL / AI_SITE_NAME — OpenRouter attribution headers
  class Client
    DEFAULT_PROVIDER = "openrouter"
    DEFAULT_TIMEOUT = 20
    CHAT_PATH = "/chat/completions"

    PROVIDER_BASE_URLS = {
      "openrouter" => "https://openrouter.ai/api/v1",
      "openai" => "https://api.openai.com/v1",
      "groq" => "https://api.groq.com/openai/v1",
      "gemini" => "https://generativelanguage.googleapis.com/v1beta/openai"
    }.freeze

    PROVIDER_DEFAULT_MODELS = {
      "openrouter" => "openrouter/free",
      "openai" => "gpt-5.4-mini",
      "groq" => "llama-3.3-70b-versatile",
      "gemini" => "gemini-2.5-flash"
    }.freeze

    def initialize(
      api_key: nil,
      provider: ENV.fetch("AI_PROVIDER", DEFAULT_PROVIDER),
      base_url: ENV["AI_BASE_URL"],
      model: ENV["AI_STRATEGY_MODEL"],
      timeout: ENV.fetch("AI_TIMEOUT_SECONDS", DEFAULT_TIMEOUT).to_i,
      site_url: ENV.fetch("AI_SITE_URL", "https://lifepoints.onrender.com"),
      site_name: ENV.fetch("AI_SITE_NAME", "LifePoints"),
      http: nil
    )
      @provider = provider.to_s.strip.downcase.presence || DEFAULT_PROVIDER
      @api_key = resolve_api_key(api_key)
      @base_url = (base_url.presence || PROVIDER_BASE_URLS[@provider] || PROVIDER_BASE_URLS[DEFAULT_PROVIDER]).to_s.chomp("/")
      @model = (model.presence || PROVIDER_DEFAULT_MODELS[@provider] || PROVIDER_DEFAULT_MODELS[DEFAULT_PROVIDER]).to_s
      @timeout = timeout.positive? ? timeout : DEFAULT_TIMEOUT
      @site_url = site_url.to_s.strip.presence
      @site_name = site_name.to_s.strip.presence
      @http = http
    end

    attr_reader :provider, :base_url, :model

    # One-shot chat completion → parsed JSON Hash
    def complete(system:, user:)
      raise Ai::ConfigurationError, "AI_API_KEY is not set" if @api_key.blank?

      body = {
        model: @model,
        temperature: 0.4,
        messages: [
          { role: "system", content: system },
          { role: "user", content: user }
        ],
        response_format: { type: "json_object" }
      }

      response = post_json(CHAT_PATH, body)
      content = extract_content(response)
      parse_json(content)
    end

    private

    def resolve_api_key(api_key)
      # Explicit argument (including blank) wins so tests can force a missing key
      # even when AI_API_KEY is present in the process environment.
      return api_key.to_s.strip.presence unless api_key.nil?

      ENV["AI_API_KEY"].presence || ENV["OPENROUTER_API_KEY"].presence || ENV["OPENAI_API_KEY"].presence
    end

    def post_json(path, payload)
      uri = URI.join("#{@base_url}/", path.delete_prefix("/"))
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      apply_openrouter_headers!(request) if openrouter?
      request.body = JSON.generate(payload)

      raw = perform(uri, request)
      parse_response_body(raw)
    end

    def openrouter?
      @provider == "openrouter" || @base_url.include?("openrouter.ai")
    end

    def apply_openrouter_headers!(request)
      request["HTTP-Referer"] = @site_url if @site_url.present?
      request["X-Title"] = @site_name if @site_name.present?
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
