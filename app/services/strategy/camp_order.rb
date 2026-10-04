# frozen_string_literal: true

module Strategy
  # Camp sequence on a plan — matches Arrange overlay (stage, then position).
  module CampOrder
    module_function

    def sort_key(project)
      [ project.try(:stage).to_i, project.position.to_i, project.id ]
    end

    def sort(projects)
      Array(projects).sort_by { |project| sort_key(project) }
    end
  end
end
