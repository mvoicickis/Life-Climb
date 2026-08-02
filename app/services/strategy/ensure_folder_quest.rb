# frozen_string_literal: true

module Strategy
  # Idempotent host day under a leaf Quest Folder for the invisible checklist.
  # Safe to call many times / under parallel requests (row lock + find-first).
  class EnsureFolderQuest
    HOST_TITLE = "Checklist"

    def self.call(folder:)
      new(folder: folder).call
    end

    def initialize(folder:)
      @folder = folder
    end

    def call
      raise ArgumentError, "folder required" if @folder.blank?
      raise ArgumentError, "folder must be a project" unless @folder.project?

      @folder.with_lock do
        existing = host_day
        return existing if existing

        # Days belong under nested leaf folders (not path-level camps).
        return nil unless @folder.nested_leaf_camp? || (@folder.project? && @folder.parent&.project?)

        @folder.children.create!(
          user: @folder.user,
          life_area: @folder.life_area,
          life_journey: @folder.life_journey,
          horizon: "day",
          title: HOST_TITLE,
          scheduled_on: Date.current,
          position: next_position,
          repeat: "none"
        )
      end
    end

    private

    def host_day
      days =
        if @folder.association(:children).loaded?
          @folder.children.select(&:day?).sort_by { |d| [ d.position.to_i, d.id ] }
        else
          @folder.children.where(horizon: "day").ordered.to_a
        end
      days.find { |d| d.title.to_s == HOST_TITLE } || days.first
    end

    def next_position
      scope = @folder.children.where(horizon: "day")
      scope.maximum(:position).to_i + 1
    end
  end
end
