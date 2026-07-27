# frozen_string_literal: true

module Strategy
  # Quiet mountain "save file" stages for the climb expedition.
  class Mountain
    STAGES = %i[empty foothill trail camp flags summit].freeze

    def self.for(goal:)
      new(goal:).call
    end

    def initialize(goal:)
      @goal = goal
    end

    def call
      return payload(stage: :empty, progress: 0, flags: 0) if @goal.blank?

      plans = @goal.children.select(&:plan?)
      projects = plans.flat_map { |p| p.children.select(&:project?) }
      completed_projects = projects.count(&:completed?)
      progress = @goal.progress_percent.to_i

      stage =
        if progress >= 100
          :summit
        elsif completed_projects.positive?
          :flags
        elsif projects.any?
          :camp
        elsif plans.any?
          :trail
        else
          :foothill
        end

      payload(stage: stage, progress: progress, flags: completed_projects)
    end

    private

    def payload(stage:, progress:, flags:)
      {
        stage: stage,
        progress: progress,
        flags: flags,
        label: narrative_label(stage, progress)
      }
    end

    # Journey words the eye can read — not just structure flags.
    def narrative_label(stage, progress)
      key =
        case stage.to_sym
        when :empty then "empty"
        when :foothill then "base_camp"
        when :trail then "trail_opening"
        when :camp then "camp_set"
        when :flags
          if progress >= 85 then "final_ascent"
          elsif progress >= 40 then "halfway_ridge"
          else "flags_raised"
          end
        when :summit then "summit"
        else stage.to_s
        end

      I18n.t("strategy.mountain.stages.#{key}", default: I18n.t("strategy.mountain.stages.#{stage}"))
    end
  end
end
