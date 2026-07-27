# frozen_string_literal: true

module Ai
  # Strategy-Space strategist: suggest titles for the current hierarchy level.
  #
  # Never writes user data. Never called from Execution Space.
  # Suggestions fill a form / are accepted by the user; Rails saves after that.
  #
  #   Ai::StrategyService.call(goal: "Earn $25,000", horizon: "plan", context: { ... })
  #   # => { "summary" => "...", "question" => "...", "suggestions" => [{ "type" => "plan", "title" => "..." }] }
  class StrategyService
    HORIZONS = %w[goal plan project day].freeze
    SUGGESTION_TYPES = HORIZONS.freeze
    DEFAULT_HORIZON = "plan"

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are the strategist for LifePoints — a goal game, not an AI app.

      Separation of roles:
      - You think and suggest.
      - The user decides.
      - The Rails app saves data after the user accepts.
      - The database is the source of truth.

      GOLDEN RULE: Never create or modify user data. Your only job is to generate suggestions.

      Hierarchy (never skip levels): Goal → Plans → Projects → Battles.
      - "day" means a Battle (one small win for a day).
      - Suggest titles ONLY for the requested horizon/level.
      - Do NOT suggest other levels. Do NOT invent obstacles, reviews, or Execution-Space tasks.

      Voice:
      - Strategist, not chatbot, not therapist.
      - Suggest, never command. Prefer "One possible approach is…", "Would you like…", "Here are a few ideas…".
      - No pep talks. No judgment. No assumptions about obstacles.

      Minimum information:
      - Return only what moves the user forward.
      - If a single clarifying question is enough, set "question" and use an empty "suggestions" array.
      - Only propose title suggestions when you understand the approach well enough.

      Output MUST be a single JSON object with exactly these keys:
      {
        "summary": "string",
        "question": "string or null",
        "suggestions": [
          { "type": "<requested_horizon>", "title": "string" }
        ]
      }

      Rules for fields:
      - "question" is a single string or null (never an array).
      - Every suggestion "type" must match the requested horizon exactly (goal, plan, project, or day).
      - "title" is short and actionable.
      - If you include suggestions, include 2–4 of them.
    PROMPT

    def self.call(goal:, horizon: DEFAULT_HORIZON, context: {}, client: Ai::Client.new)
      new(goal:, horizon:, context:, client:).call
    end

    def initialize(goal:, horizon: DEFAULT_HORIZON, context: {}, client: Ai::Client.new)
      @goal = goal.to_s.strip
      @horizon = normalize_horizon(horizon)
      @context = context.is_a?(Hash) ? context : {}
      @client = client
    end

    def call
      raise Ai::Error, "goal is required" if @goal.blank?

      raw = @client.complete(system: SYSTEM_PROMPT, user: user_prompt)
      normalize(raw)
    end

    private

    def normalize_horizon(value)
      key = value.to_s.strip.downcase
      return DEFAULT_HORIZON if key.blank?

      return key if HORIZONS.include?(key)
      return "day" if key.in?(%w[battle battles])
      return "project" if key.in?(%w[projects])
      return "plan" if key.in?(%w[plans])
      return "goal" if key.in?(%w[goals mountain])

      DEFAULT_HORIZON
    end

    def user_prompt
      level_label = @horizon == "day" ? "battle (day)" : @horizon
      lines = [
        "Requested horizon: #{@horizon}",
        "Suggest titles for: #{level_label}",
        "Goal: #{@goal}"
      ]

      ideal = value_for(:ideal_scene)
      reality = value_for(:current_reality)
      area = value_for(:life_area)
      goal_title = value_for(:goal_title)
      plan_title = value_for(:plan_title)
      project_title = value_for(:project_title)

      lines << "Ideal scene: #{ideal}" if ideal
      lines << "Current reality: #{reality}" if reality
      lines << "Life area: #{area}" if area
      lines << "Parent Goal title: #{goal_title}" if goal_title.present? && goal_title != @goal
      lines << "Parent Plan title: #{plan_title}" if plan_title
      lines << "Parent Project title: #{project_title}" if project_title
      lines << "Respond with JSON only (summary, question, #{@horizon} suggestions)."
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

        { "type" => @horizon, "title" => title }
      else
        title = item.to_s.strip
        return nil if title.blank?

        { "type" => @horizon, "title" => title }
      end
    end
  end
end
