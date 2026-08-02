# frozen_string_literal: true

module Strategy
  # Plan-scoped climb presenter for Mountain Focus.
  # Phase 1 trail nodes = Projects under a Plan.
  # Phase 2 can swap nodes to Programs without rewriting the views.
  class Trail
    # Default server window: previous cleared + current + next fogged.
    VISIBLE_AHEAD = 1
    VISIBLE_BEHIND = 1

    Node = Struct.new(
      :id, :title, :state, :pct, :position, :record, :y,
      keyword_init: true
    )

    Result = Struct.new(
      :progress, :nodes, :visible_nodes, :current_node, :next_node, :plan, :label,
      keyword_init: true
    )

    def self.for(plan:)
      new(plan:).call
    end

    def initialize(plan:)
      @plan = plan
    end

    def call
      return empty_result if @plan.blank?

      projects = ordered_projects
      nodes = build_nodes(projects)
      current = nodes.find { |n| n.state == :current } || nodes.reverse.find { |n| n.state == :done }
      nxt = nodes.find { |n| n.state == :locked && current && n.position > current.position } ||
            nodes.find { |n| n.state == :current && n != current }

      Result.new(
        progress: @plan.progress_percent.to_i,
        nodes: nodes,
        visible_nodes: focused_sequence(nodes, current),
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
          kids.select(&:project?)
        else
          Array(kids).select { |c| c.respond_to?(:project?) ? c.project? : c.horizon.to_s == "project" }
        end
      projects.sort_by { |p| [ p.position.to_i, p.id ] }
    end

    def build_nodes(projects)
      return [] if projects.empty?

      current_index = projects.index { |p| !p.completed? } || projects.length
      count = projects.length

      projects.each_with_index.map do |project, index|
        state =
          if project.completed?
            :done
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

    def focused_sequence(nodes, current)
      return nodes if nodes.size <= (VISIBLE_BEHIND + VISIBLE_AHEAD + 1)

      idx = current ? current.position : 0
      from = [ idx - VISIBLE_BEHIND, 0 ].max
      to = [ idx + VISIBLE_AHEAD, nodes.length - 1 ].min
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
