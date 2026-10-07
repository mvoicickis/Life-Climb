# frozen_string_literal: true

module Strategy
  # Plan-scoped climb presenter for Mountain Focus.
  # Phase 1 trail nodes = Projects under a Plan.
  # Phase 2 can swap nodes to Programs without rewriting the views.
  class Trail
    # Map window: up to three camps along trail order (array index, not position column).
    VISIBLE_MAX = 3
    VISIBLE_BEHIND = 0

    Node = Struct.new(
      :id, :title, :state, :pct, :position, :record, :y,
      keyword_init: true
    )

    Result = Struct.new(
      :progress, :nodes, :visible_nodes, :current_node, :next_node, :plan, :label,
      keyword_init: true
    )

    def self.for(plan:, ensure_visible_id: nil)
      new(plan:, ensure_visible_id:).call
    end

    # Path spine: first sequential open camp in CampOrder (not tracker-linked).
    def self.current_camp_for(plan:)
      new(plan: plan).current_camp_for
    end

    def initialize(plan:, ensure_visible_id: nil)
      @plan = plan
      @ensure_visible_id = ensure_visible_id
    end

    def call
      return empty_result if @plan.blank?

      projects = ordered_projects
      nodes = build_nodes(projects)
      current = nodes.find { |n| n.state == :current } || nodes.reverse.find { |n| n.state == :done }
      nxt = next_node_after(nodes, current)

      visible = visible_nodes_from(nodes, current, ensure_visible_id: @ensure_visible_id)

      Result.new(
        progress: @plan.progress_percent.to_i,
        nodes: nodes,
        visible_nodes: visible,
        current_node: current,
        next_node: nxt,
        plan: @plan,
        label: narrative_label(nodes, @plan.progress_percent.to_i)
      )
    end

    def current_camp_for
      return nil if @plan.blank?

      projects = ordered_projects
      return nil if projects.empty?

      index = self.class.current_index_for(projects)
      return nil if index >= projects.length

      camp = projects[index]
      return nil unless camp.path_level_camp?

      camp
    end

    def self.current_index_for(projects)
      list = Array(projects)
      list.index { |p| !p.completed? && !tracker_linked?(p) } || list.length
    end

    def self.tracker_linked?(project)
      return false if project.blank?
      return project.tracker_linked? if project.respond_to?(:tracker_linked?)

      false
    end

    private

    def empty_result
      Result.new(
        progress: 0,
        nodes: [],
        visible_nodes: [],
        current_node: nil,
        next_node: nil,
        plan: @plan,
        label: I18n.t("strategy.rpg.trail.empty", default: "Pick a path to climb")
      )
    end

    def ordered_projects
      kids = @plan.children
      projects =
        if kids.respond_to?(:select)
          kids.select { |p| p.project? && !p.holding? }
        else
          Array(kids).select { |c| c.respond_to?(:project?) ? (c.project? && !c.holding?) : c.horizon.to_s == "project" }
        end
      CampOrder.sort(projects)
    end

    def build_nodes(projects)
      return [] if projects.empty?

      # Sequential lock ignores Tracker-linked Projects (habit_project_links) so they
      # never block the Path queue — and so they never sit as :locked themselves.
      current_index = self.class.current_index_for(projects)
      count = projects.length

      projects.each_with_index.map do |project, index|
        state =
          if project.completed?
            :done
          elsif tracker_linked?(project)
            :current
          elsif index == current_index
            :current
          elsif index < current_index
            :done
          else
            :locked
          end

        # Spread checkpoints from base (88%) toward summit (12%).
        y = count == 1 ? 50.0 : (88.0 - (index.to_f / (count - 1)) * 76.0)

        Node.new(
          id: project.id,
          title: project.title,
          state: state,
          pct: project.progress_percent.to_i,
          position: index,
          record: project,
          y: y.round(1)
        )
      end
    end

    def tracker_linked?(project)
      self.class.tracker_linked?(project)
    end

    def visible_nodes_from(nodes, current, ensure_visible_id: nil)
      return [] if nodes.present? && nodes.all? { |node| node.state == :done }

      current_idx =
        if current
          nodes.index { |node| node.id == current.id } || 0
        else
          0
        end

      forward = Array(nodes[current_idx..]).reject { |node| node.state == :done }
      visible = forward.take(VISIBLE_MAX)

      if ensure_visible_id.present? && visible.none? { |node| node.id == ensure_visible_id }
        pinned_idx = nodes.index { |node| node.id == ensure_visible_id }
        if pinned_idx
          from = [ pinned_idx - VISIBLE_MAX + 1, 0 ].max
          pinned_slice = Array(nodes[from..pinned_idx]).reject { |node| node.state == :done }
          visible = pinned_slice.take(VISIBLE_MAX)
        end
      end

      visible
    end

    def next_node_after(nodes, current)
      return nil if current.blank?

      current_idx = nodes.index { |node| node.id == current.id }
      return nil if current_idx.nil?

      Array(nodes[(current_idx + 1)..]).find { |node| node.state != :done } ||
        nodes.find { |node| node.state == :current && node.id != current.id }
    end

    def narrative_label(nodes, progress)
      return I18n.t("strategy.rpg.trail.empty", default: "Pick a path to climb") if nodes.empty?
      return I18n.t("strategy.rpg.trail.summit", default: "Standing at the summit") if progress >= 100

      current = nodes.find { |n| n.state == :current }
      if current
        I18n.t("strategy.rpg.trail.at_checkpoint", title: current.title, default: "At %{title}")
      else
        I18n.t("strategy.rpg.on_my_way", default: "On my way")
      end
    end
  end
end
