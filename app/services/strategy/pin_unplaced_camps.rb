# frozen_string_literal: true

module Strategy
  # Write auto trail coords once so unplanted camps stop jumping on refresh.
  class PinUnplacedCamps
    def self.call(projects:)
      new(projects).call
    end

    def initialize(projects)
      @projects = Array(projects).compact
    end

    def call
      return if @projects.none? { |project| unplaced?(project) }

      total = @projects.size
      sparse = total <= 2
      @projects.each_with_index do |project, index|
        next unless unplaced?(project)

        slot = MountainTrailHelper::AutoSlot.call(index: index, total: total, sparse: sparse)
        project.update_columns(
          trail_x: slot[:trail_x],
          trail_y: slot[:trail_y],
          updated_at: Time.current
        )
      end
    end

    private

    def unplaced?(project)
      project.trail_x.blank? || project.trail_y.blank?
    end
  end
end
