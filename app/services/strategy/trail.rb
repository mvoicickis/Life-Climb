# frozen_string_literal: true

module Strategy
  # Plan-scoped climb presenter for Mountain Focus.
  # Phase 1 trail nodes = Projects under a Plan.
  # Phase 2 can swap nodes to Programs without rewriting the views.
  class Trail
    # Map window: up to three camps along trail order (array index, not position column).
    VISIBLE_MAX = 3
    VISIBLE_BEHIND = 1

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

    def initialize(plan:, ensure_visible_id: nil)
      @plan = plan
      @ensure_visible_id = ensure_visible_id
    end

    def call
      return empty_result if @plan.blank?

      projects = ordered_projects
      nodes = build_nodes(projects)
      current = nodes.find { |n| n.state == :current } || nodes.reverse.find { |n| n.state == :done }
      nxt = nodes.find { |n| n.state == :locked && current && n.position > current.position } ||
            nodes.find { |n| n.state == :current && n != current }

      visible = focused_sequence(nodes, current, ensure_visible_id: @ensure_visible_id)

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
      projects.sort_by { |p| [ p.position.to_i, p.id ] }
    end

    def build_nodes(projects)
      return [] if projects.empty?

      # Sequential lock ignores Tracker-linked Projects (habit_project_links) so they
      # never block the Path queue — and so they never sit as :locked themselves.
      current_index =
        projects.index { |p| !p.completed? && !tracker_linked?(p) } || projects.length
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
      return false if project.blank?
      return project.tracker_linked? if project.respond_to?(:tracker_linked?)

      false
    end

    def focused_sequence(nodes, current, ensure_visible_id: nil)
      slice = default_focused_slice(nodes, current)
      return slice if ensure_visible_id.blank?
      return slice if slice.any? { |node| node.id == ensure_visible_id }

      pinned_idx = nodes.index { |node| node.id == ensure_visible_id }
      return slice if pinned_idx.nil?

      to = pinned_idx
      from = [ to - VISIBLE_MAX + 1, 0 ].max
      adjusted = nodes[from..to]

      # region agent log
      File.open(Rails.root.join(".cursor/debug-13d410.log"), "a") do |f|
        f.puts(
          {
            sessionId: "13d410",
            hypothesisId: "H1",
            location: "strategy/trail.rb:focused_sequence",
            message: "ensure_visible_id shifted map window",
            data: {
              ensure_visible_id: ensure_visible_id,
              default_ids: slice.map(&:id),
              adjusted_ids: adjusted.map(&:id),
              pinned_idx: pinned_idx
            },
            timestamp: (Time.now.to_f * 1000).to_i
          }.to_json
        )
      end
      # endregion

      adjusted
    end

    def default_focused_slice(nodes, current)
      return nodes if nodes.size <= VISIBLE_MAX

      unless current
        return nodes.last(VISIBLE_MAX)
      end

      idx = nodes.index { |node| node.id == current.id } || 0
      from = idx.zero? ? 0 : idx - VISIBLE_BEHIND
      to = from + VISIBLE_MAX - 1

      if to >= nodes.length
        to = nodes.length - 1
        from = [ to - VISIBLE_MAX + 1, 0 ].max
      end

      nodes[from..to]
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
