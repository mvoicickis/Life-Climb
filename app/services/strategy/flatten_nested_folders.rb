# frozen_string_literal: true

module Strategy
  # One-time flatten: nested quest folders collapse onto their path-level camp.
  # Days move up (stable order). Empty folders are deleted. Not reversible.
  class FlattenNestedFolders
    def self.call
      new.call
    end

    def call
      path_camps.find_each do |camp|
        flatten_camp!(camp)
      end
    end

    private

    def path_camps
      plan_ids = StrategyGoal.where(horizon: "plan").select(:id)
      StrategyGoal.where(horizon: "project", parent_id: plan_ids).order(:id)
    end

    def flatten_camp!(camp)
      nested = nested_folders_under(camp)
      return if nested.empty?

      copy_folder_colors_onto_days!(nested)
      promote_path_camp_color!(camp, nested)

      ordered_days = collect_days_in_order(camp)
      ordered_days.each_with_index do |day, index|
        StrategyGoal.where(id: day.id).update_all(
          parent_id: camp.id,
          position: index,
          updated_at: Time.current
        )
      end

      nested.reverse_each do |folder|
        next unless StrategyGoal.exists?(folder.id)

        folder.reload
        folder.destroy!
      end

      camp.children.reset
      Strategy::SyncCompletion.resync!(node: camp.reload)
    end

    def nested_folders_under(camp)
      folders = []
      frontier = [ camp.id ]
      while frontier.any?
        kids = StrategyGoal.where(parent_id: frontier, horizon: "project").order(:position, :id).to_a
        break if kids.empty?

        folders.concat(kids)
        frontier = kids.map(&:id)
      end
      folders
    end

    def collect_days_in_order(node)
      days = StrategyGoal.where(parent_id: node.id, horizon: "day").order(:position, :id).to_a
      StrategyGoal.where(parent_id: node.id, horizon: "project").order(:position, :id).to_a.each do |folder|
        days.concat(collect_days_in_order(folder))
      end
      days
    end

    def copy_folder_colors_onto_days!(folders)
      folders.each do |folder|
        key = folder.color_key.to_s.presence
        next if key.blank?

        StrategyGoal.where(parent_id: folder.id, horizon: "day").update_all(
          color_key: key,
          updated_at: Time.current
        )
      end
    end

    def promote_path_camp_color!(camp, folders)
      return if camp.color_key.present?

      colors = folders.map { |folder| folder.color_key.to_s.presence }.compact.uniq
      return unless colors.size == 1

      camp.update_columns(color_key: colors.first, updated_at: Time.current)
    end
  end
end
