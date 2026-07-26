# frozen_string_literal: true

module Strategy
  # Suggests sharper next-battle titles when a project is still open after a win.
  class BattleAngles
    LIMIT = 3

    def self.for(project:)
      new(project:).call
    end

    def self.valid_title?(project:, title:)
      self.for(project: project).include?(title.to_s.strip)
    end

    def initialize(project:)
      @project = project
    end

    def call
      return [] unless @project&.project? && @project.completed_at.blank?

      existing = existing_titles
      candidates.filter_map do |title|
        cleaned = title.to_s.strip.truncate(80)
        next if cleaned.blank?
        next if existing.include?(cleaned.downcase)

        cleaned
      end.first(LIMIT)
    end

    private

    def existing_titles
      @project.children.battles.map { |b| b.title.to_s.strip.downcase }
    end

    def last_battle_title
      @project.children.battles.order(completed_at: :desc, id: :desc).first&.title.presence ||
        @project.children.battles.ordered.last&.title
    end

    def candidates
      project = @project.title.to_s.strip
      last = last_battle_title.to_s.strip

      [
        I18n.t("dash.battle_angles.templates.fifteen", project: project),
        (I18n.t("dash.battle_angles.templates.harder", battle: last) if last.present?),
        I18n.t("dash.battle_angles.templates.blocker", project: project),
        I18n.t("dash.battle_angles.templates.prep", project: project),
        I18n.t("dash.battle_angles.templates.smallest", project: project)
      ].compact
    end
  end
end
