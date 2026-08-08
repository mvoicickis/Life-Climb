# frozen_string_literal: true

module Battles
  # Nested camp parent for a new day battle (same rules as BattleAnglesController).
  class PracticeParent
    def self.call(user:, project:)
      new(user: user, project: project).call
    end

    def initialize(user:, project:)
      @user = user
      @project = project
    end

    def call
      return @project if @project.parent&.project?

      leaf = @project.children.detect { |child| child.project? && child.leaf_checkpoint? }
      return leaf if leaf

      position = @project.children.maximum(:position).to_i
      nested = @project.children.create!(
        user: @user,
        life_area: @project.life_area,
        life_journey_id: @project.life_journey_id,
        horizon: "project",
        title: I18n.t("strategy.first_climb.nested_camp_title"),
        position: position
      )
      Strategy::SyncCompletion.resync!(node: nested)
      nested
    end
  end
end
