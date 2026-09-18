# frozen_string_literal: true

module Strategy
  # Assigns a saved plan camp to the next terrace stage and fixes trail position.
  module PlaceCampOnNewTerrace
    extend MountainTrailHelper

    def self.call(plan:, camp:)
      raise ArgumentError, "plan_missing" if plan.blank? || !plan.plan?
      raise ArgumentError, "camp_missing" if camp.blank? || !camp.project?

      trail = Strategy::Trail.for(plan: plan.reload)
      projects = mountain_trail_all_projects(trail).reject { |project| project.id == camp.id }
      stage = mountain_trail_next_arrange_stage(projects)
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
  end
end
