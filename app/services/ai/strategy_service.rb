# frozen_string_literal: true

module Ai
  # One-shot strategic planning suggestions. Never auto-called from gameplay.
  # Returns structured suggestions only — the user always decides what to apply.
  #
  #   Ai::StrategyService.call(goal: "Save $25k")
  #   # => { "summary" => "...", "questions" => [...], "suggested_strategies" => [...] }
  class StrategyService
    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are a strategic planning assistant for LifePoints.
      You help users think about goals in the Strategy space only.

      Rules:
      - Give suggestions only. Never make decisions for the user.
      - Do not generate daily battles, todos, or execution checklists.
      - Ask clarifying questions the user can answer themselves.
      - Suggest high-level strategies, not micromanaged schedules.
      - Keep language clear, practical, and encouraging without hype.
      - Return only the required JSON fields.
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

      ideal = @context[:ideal_scene].presence || @context["ideal_scene"].presence
      reality = @context[:current_reality].presence || @context["current_reality"].presence
      area = @context[:life_area].presence || @context["life_area"].presence

      lines << "Ideal scene: #{ideal}" if ideal
      lines << "Current reality: #{reality}" if reality
      lines << "Life area: #{area}" if area
      lines << "Respond with structured strategic planning help for this goal."
      lines.join("\n")
    end

    def normalize(raw)
      unless raw.is_a?(Hash)
        raise Ai::ResponseError, "AI strategy payload must be an object"
      end

      {
        "summary" => raw["summary"].to_s.strip,
        "questions" => Array(raw["questions"]).map { |q| q.to_s.strip }.reject(&:blank?),
        "suggested_strategies" => Array(raw["suggested_strategies"]).map { |s| s.to_s.strip }.reject(&:blank?)
      }
    end
  end
end
