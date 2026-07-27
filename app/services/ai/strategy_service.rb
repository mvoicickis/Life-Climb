# frozen_string_literal: true

module Ai
  # Phase 1 strategist: Goal → optional one question → 2–4 suggested plans.
  #
  # Never writes user data. Never called from Execution Space.
  # Suggestions become Plans only after the user accepts them (later UI + Rails).
  #
  #   Ai::StrategyService.call(goal: "Earn $25,000 in 12 months", context: { ... })
  #   # => { "summary" => "...", "question" => "...", "suggestions" => [{ "type" => "plan", "title" => "..." }] }
  class StrategyService
    SUGGESTION_TYPES = %w[plan].freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are the strategist for LifePoints — a goal game, not an AI app.

      Separation of roles:
      - You think and suggest.
      - The user decides.
      - The Rails app saves data after the user accepts.
      - The database is the source of truth.

      GOLDEN RULE: Never create or modify user data. Your only job is to generate suggestions.

      Phase 1 scope (strict):
      - Help with a Goal only.
      - Optionally ask ONE short clarifying question.
      - Suggest 2–4 Plans under that Goal (as suggestions, not saved Plans).
      - Do NOT suggest Projects, Battles, obstacles, reviews, or daily tasks.
      - Do NOT skip hierarchy levels. Hierarchy is always Goal → Plans → Projects → Battles.

      Voice:
      - Strategist, not chatbot, not therapist.
      - Suggest, never command. Prefer "One possible approach is…", "Would you like…", "Here are a few ideas…".
      - No pep talks. No judgment. No assumptions about obstacles.

      Minimum information:
      - Return only what moves the user forward.
      - If a single clarifying question is enough, set "question" and use an empty "suggestions" array.
      - Only propose plan suggestions when you understand the approach well enough.

      Output MUST be a single JSON object with exactly these keys:
      {
        "summary": "string",
        "question": "string or null",
        "suggestions": [
          { "type": "plan", "title": "string" }
        ]
      }

      Rules for fields:
      - "question" is a single string or null (never an array).
      - Every suggestion "type" must be "plan" in Phase 1.
      - "title" is short and actionable.
      - If you include plan suggestions, include 2–4 of them.
    PROMPT

    def self.call(goal:, context: {}, client: Ai::Client.new)
      new(goal:, context:, client:).call
    end

    def initialize(goal:, context: {}, client: Ai::Client.new)
      @goal = goal.to_s.strip
      @context = context.is_a?(Hash) ? context : {}
      @client = client
    end

    def call
      raise Ai::Error, "goal is required" if @goal.blank?

      raw = @client.complete(system: SYSTEM_PROMPT, user: user_prompt)
      normalize(raw)
    end

    private

    def user_prompt
      lines = [ "Goal: #{@goal}" ]

      ideal = value_for(:ideal_scene)
      reality = value_for(:current_reality)
      area = value_for(:life_area)

      lines << "Ideal scene: #{ideal}" if ideal
      lines << "Current reality: #{reality}" if reality
      lines << "Life area: #{area}" if area
      lines << "Respond with Phase 1 JSON only (summary, question, plan suggestions)."
      lines.join("\n")
    end

    def value_for(key)
      @context[key].presence || @context[key.to_s].presence
    end

    def normalize(raw)
      unless raw.is_a?(Hash)
        raise Ai::ResponseError, "AI strategy payload must be an object"
      end

      {
        "summary" => raw["summary"].to_s.strip,
        "question" => normalize_question(raw),
        "suggestions" => normalize_suggestions(raw)
      }
    end

    def normalize_question(raw)
      if raw.key?("question")
        q = raw["question"]
        return nil if q.nil? || q == false

        return q.to_s.strip.presence
      end

      questions = Array(raw["questions"]).map { |item| item.to_s.strip }.reject(&:blank?)
      questions.first
    end

    def normalize_suggestions(raw)
      list = raw["suggestions"]
      list = raw["plans"] || raw["strategies"] || raw["suggested_strategies"] if list.blank?

      Array(list).filter_map { |item| normalize_suggestion(item) }.first(4)
    end

    def normalize_suggestion(item)
      case item
      when Hash
        title = (item["title"] || item[:title] || item["text"] || item[:text]).to_s.strip
        return nil if title.blank?

        { "type" => "plan", "title" => title }
      else
        title = item.to_s.strip
        return nil if title.blank?

        { "type" => "plan", "title" => title }
      end
    end
  end
end
