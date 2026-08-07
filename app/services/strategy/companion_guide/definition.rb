# frozen_string_literal: true

module Strategy
  module CompanionGuide
    # Declarative templates for the scripted companion guide.
    # Loops are person-driven via continue_step / continue_project (repeat|advance).
    # MAX_* ceilings are backend safety only — never product-facing limits.
    class Definition
      Template = Data.define(:id, :kind, :question_key, :answer_keys)

      MAX_PROJECTS = 20
      MAX_STEPS_PER_PROJECT = 20

      DECISION_KINDS = %w[continue_step continue_project].freeze
      WRITE_KINDS = %w[create_plan set_effort_tier create_project create_day].freeze
      DECISION_VALUES = %w[repeat advance].freeze

      TEMPLATES = [
        Template.new(
          id: "create_plan",
          kind: "create_plan",
          question_key: "strategy.companion_guide.questions.create_plan",
          answer_keys: nil
        ),
        Template.new(
          id: "set_effort_tier",
          kind: "set_effort_tier",
          question_key: "strategy.companion_guide.questions.set_effort_tier",
          answer_keys: %w[light steady heavy].map { |t| "strategy.companion_guide.answers.effort_tier.#{t}" }
        ),
        Template.new(
          id: "create_project",
          kind: "create_project",
          question_key: "strategy.companion_guide.questions.create_project",
          answer_keys: nil
        ),
        Template.new(
          id: "create_day",
          kind: "create_day",
          question_key: "strategy.companion_guide.questions.create_day",
          answer_keys: nil
        ),
        Template.new(
          id: "continue_step",
          kind: "continue_step",
          question_key: "strategy.companion_guide.questions.continue_step",
          answer_keys: %w[
            strategy.companion_guide.answers.continue.repeat_step
            strategy.companion_guide.answers.continue.advance_step
          ]
        ),
        Template.new(
          id: "continue_project",
          kind: "continue_project",
          question_key: "strategy.companion_guide.questions.continue_project",
          answer_keys: %w[
            strategy.companion_guide.answers.continue.repeat_project
            strategy.companion_guide.answers.continue.advance_project
          ]
        )
      ].freeze

      BY_ID = TEMPLATES.index_by(&:id).freeze

      def self.template(id)
        BY_ID.fetch(id.to_s)
      rescue KeyError
        raise ArgumentError, "unknown companion guide template: #{id}"
      end

      def self.decision_kind?(kind)
        DECISION_KINDS.include?(kind.to_s)
      end

      def self.write_kind?(kind)
        WRITE_KINDS.include?(kind.to_s)
      end

      # Next template id after a successful data-entry answer (before decision branching).
      def self.next_after_write(template_id)
        case template_id.to_s
        when "create_plan" then "set_effort_tier"
        when "set_effort_tier" then "create_project"
        when "create_project" then "create_day"
        when "create_day" then "continue_step"
        else
          raise ArgumentError, "no write-advance for #{template_id}"
        end
      end
    end
  end
end
