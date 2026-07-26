# frozen_string_literal: true

module Strategy
  # Quiet mountain "save file" stages for the Strategy expedition.
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
      completed_projects = projects.count { |p| p.progress_percent.to_i >= 100 }
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
        label: I18n.t("strategy.mountain.stages.#{stage}")
      }
    end
  end
end
