# frozen_string_literal: true

module Strategy
  # Assigns a saved plan camp to the next terrace stage and fixes trail position.
  module PlaceCampOnNewTerrace
    def self.call(plan:, camp:)
      raise ArgumentError, "plan_missing" if plan.blank? || !plan.plan?
      raise ArgumentError, "camp_missing" if camp.blank? || !camp.project?

      trail = Strategy::Trail.for(plan: plan.reload)
      projects = plan_projects(trail).reject { |project| project.id == camp.id }
      stage = next_terrace_stage(projects)
      place_on_stage!(plan: plan, camp: camp, stage: stage)
    end

    def self.place_on_stage!(plan:, camp:, stage:)
      stage = stage.to_i
      raise ArgumentError, "bad_stage" if stage.negative?

      camp.stage = stage
      camp.stage_explicit = true
      camp.save! if camp.changed?

      Strategy::PlaceCampOnStage.call(plan: plan, camp: camp, stage: stage)
      camp.reload
    end

    def self.plan_projects(trail)
      Array(trail&.nodes).filter_map(&:record).reject(&:holding?)
    end

    def self.next_terrace_stage(projects)
      stages = Array(projects).map { |project| project.stage.to_i }
      (stages.empty? ? -1 : stages.max) + 1
    end
  end
end
