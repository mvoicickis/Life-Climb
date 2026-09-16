# frozen_string_literal: true

module Strategy
  # Inserts a camp onto a terrace stage and shifts later camps so Trail position
  # order matches stage order (open stage + Trail :current stay aligned).
  class PlaceCampOnStage
    class Invalid < StandardError; end

    def self.call(plan:, camp:, stage:)
      new(plan: plan, camp: camp, stage: stage).call
    end

    def initialize(plan:, camp:, stage:)
      @plan = plan
      @camp = camp
      @stage = stage.to_i
    end

    def call
      validate!

      StrategyGoal.transaction do
        others = plan_camps.reject { |c| c.id == @camp.id }
        later = others.select { |c| c.stage.to_i > @stage }
        insert_pos =
          if later.any?
            later.map { |c| c.position.to_i }.min
          else
            (others.map { |c| c.position.to_i }.max || -1) + 1
          end

        touch = Time.current
        others
          .select { |c| c.position.to_i >= insert_pos }
          .sort_by { |c| -c.position.to_i }
          .each do |sibling|
            sibling.update_columns(position: sibling.position.to_i + 1, updated_at: touch)
          end

        @camp.update_columns(stage: @stage, position: insert_pos, updated_at: touch)
      end

      @camp.reload
    end

    private

    def validate!
      raise Invalid, "plan_missing" if @plan.blank? || !@plan.plan?
      raise Invalid, "camp_missing" if @camp.blank? || !@camp.project?
      raise Invalid, "camp_mismatch" unless @camp.parent_id == @plan.id
      raise Invalid, "holding" if @camp.holding?
    end

    def plan_camps
      @plan.children.select { |c| c.project? && !c.holding? }
    end
  end
end
