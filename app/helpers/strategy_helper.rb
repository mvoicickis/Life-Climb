# frozen_string_literal: true

module StrategyHelper
  CHILD_HORIZON = {
    "goal" => "plan",
    "plan" => "project",
    "project" => "day"
  }.freeze

  VISIBLE_PER_LEVEL = 3

  # Center trail slots — slightly compressed so the climb reads as one trail.
  GOAL_SLOT = [ 50, 14 ].freeze
  SELECTED_PLAN_SLOT = [ 50, 32 ].freeze
  SELECTED_PROJECT_SLOT = [ 50, 50 ].freeze
  SELECTED_BATTLE_SLOT = [ 50, 68 ].freeze
  CAMP_SLOT = [ 50, 86 ].freeze
  CAMP_TOP_AT_ZERO = 86.0
  CAMP_TOP_AT_SUMMIT = 16.0
  PILL_SLOTS = [
    [ 16, 22 ], [ 84, 22 ], [ 12, 34 ], [ 88, 34 ], [ 14, 42 ], [ 86, 42 ]
  ].freeze
  SIBLING_PROJECT_SLOTS = [
    [ 30, 50 ], [ 70, 50 ]
  ].freeze
  SIBLING_BATTLE_SLOTS = [
    [ 30, 68 ], [ 70, 68 ]
  ].freeze
  PLAN_OVERFLOW_SLOT = [ 50, 42 ].freeze
  PROJECT_OVERFLOW_SLOT = [ 88, 54 ].freeze
  BATTLE_OVERFLOW_SLOT = [ 88, 72 ].freeze
  FLAG_SLOTS = {
    "goal" => [ 58, 12 ],
    "plan" => [ 58, 30 ],
    "project" => [ 58, 48 ],
    "battle" => [ 58, 66 ]
  }.freeze
  # Spine tops for fog/cleared math (goal → camp default).
  SPINE_TOPS = [ 14.0, 32.0, 50.0, 68.0, 86.0 ].freeze

  def strategy_kind_css(node)
    node.day? ? "battle" : node.kind
  end

  def strategy_child_horizon(node)
    CHILD_HORIZON[node.kind]
  end

  def strategy_add_label(node)
    case strategy_child_horizon(node)
    when "plan" then I18n.t("strategy.sheet.add_plan")
    when "project" then I18n.t("strategy.sheet.add_project")
    when "day" then I18n.t("strategy.sheet.add_battle")
    else I18n.t("strategy.sheet.add_child")
    end
  end

  def strategy_help_label(node)
    case strategy_child_horizon(node)
    when "plan" then I18n.t("strategy.help.suggest_plan")
    when "project" then I18n.t("strategy.help.suggest_project")
    when "day" then I18n.t("strategy.help.suggest_battle")
    else I18n.t("strategy.help.cta")
    end
  end

  def strategy_delete_confirm(node)
    plans = node.goal? ? node.children.count { |c| c.plan? } : 0
    projects =
      if node.goal?
        node.children.select(&:plan?).sum { |p| p.children.count { |c| c.project? } }
      elsif node.plan?
        node.children.count { |c| c.project? }
      else
        0
      end
    battles =
      if node.day?
        0
      else
        Strategy::Progress.battles_under(node).size
      end

    parts = []
    parts << I18n.t("strategy.delete_confirm.plans", count: plans) if plans.positive?
    parts << I18n.t("strategy.delete_confirm.projects", count: projects) if projects.positive?
    parts << I18n.t("strategy.delete_confirm.battles", count: battles) if battles.positive?

    if parts.empty?
      I18n.t("strategy.delete_confirm.simple", title: node.title)
    else
      I18n.t("strategy.delete_confirm.with_children", title: node.title, list: parts.join("\n"))
    end
  end

  def strategy_parent_titles(node)
    goal = node.goal? ? node : node.root_goal
    plan = node.plan? ? node : node.ancestor_chain.find(&:plan?)
    project = node.project? ? node : (node.day? ? node.parent : nil)
    {
      goal_title: goal&.title.to_s,
      plan_title: plan&.title.to_s,
      project_title: project&.title.to_s
    }
  end

  def strategy_projects_count(plan)
    plan.children.count { |c| c.project? }
  end

  def strategy_battles_count(project)
    project.children.count { |c| c.day? }
  end

  def strategy_camp_percent(mountain)
    mountain[:progress].to_i.clamp(0, 100)
  end

  # Camp climbs the trail as progress rises (bottom → summit).
  def strategy_camp_slot(progress)
    pct = progress.to_i.clamp(0, 100) / 100.0
    top = CAMP_TOP_AT_ZERO - ((CAMP_TOP_AT_ZERO - CAMP_TOP_AT_SUMMIT) * pct)
    { left: 50, top: top.round(1) }
  end

  def strategy_camp_you_label(user = current_user)
    first = user&.display_name.to_s.split(/\s+/).first.presence
    first.presence || I18n.t("strategy.zones.you")
  end

  def strategy_climb_streak(user = current_user)
    Climb::Streak.current(user: user)
  end

  def strategy_climb_streak_status(user = current_user)
    Climb::Streak.status(user: user)
  end

  # Visual-only difficulty for mockup battle pills (reward bands).
  def strategy_battle_difficulty(reward)
    n = reward.to_i
    return "easy" if n <= 15
    return "hard" if n >= 45

    "medium"
  end

  # Segment is cleared when its lower endpoint sits at/below the camp line.
  def strategy_segment_cleared?(to_slot, camp_slot)
    to_slot[:top].to_f >= camp_slot[:top].to_f - 0.5
  end

  def strategy_pin_state(node:, today: false)
    return "today" if today
    return "cleared" if node.completed?

    "ahead"
  end

  def strategy_peek_primary(node)
    kind = strategy_kind_css(node)
    case kind
    when "goal"
      { label: I18n.t("climb.peek.open_trail"), action: "focus" }
    when "plan"
      { label: I18n.t("climb.peek.add_next"), action: "add" }
    when "project"
      { label: I18n.t("climb.peek.make_battle"), action: "add" }
    when "battle"
      if node.completed?
        { label: I18n.t("climb.peek.open_trail"), action: "focus" }
      else
        { label: I18n.t("climb.peek.fight_today"), action: "fight" }
      end
    else
      { label: I18n.t("climb.peek.open_trail"), action: "focus" }
    end
  end

  def strategy_trail_slot(kind, index = 0)
    slots =
      case kind.to_s
      when "goal" then [ GOAL_SLOT ]
      when "plan", "selected_plan" then [ SELECTED_PLAN_SLOT ]
      when "selected_project" then [ SELECTED_PROJECT_SLOT ]
      when "selected_battle" then [ SELECTED_BATTLE_SLOT ]
      when "pill" then PILL_SLOTS
      when "project" then SIBLING_PROJECT_SLOTS
      when "battle", "day" then SIBLING_BATTLE_SLOTS
      when "plan_overflow" then [ PLAN_OVERFLOW_SLOT ]
      when "project_overflow" then [ PROJECT_OVERFLOW_SLOT ]
      when "battle_overflow" then [ BATTLE_OVERFLOW_SLOT ]
      when "camp" then [ CAMP_SLOT ]
      else [ [ 50, 50 ] ]
      end
    # Callers must cap indexes — never silently stack two pins on one slot.
    safe_index = index.to_i
    raise ArgumentError, "trail slot index #{safe_index} out of range for #{kind}" if safe_index.negative? || safe_index >= slots.length

    left, top = slots[safe_index]
    { left: left, top: top }
  end

  def strategy_flag_slot(kind)
    left, top = FLAG_SLOTS.fetch(kind.to_s, [ 58, 50 ])
    { left: left, top: top }
  end

  def strategy_visible_nodes(nodes, selected_id = nil, limit: VISIBLE_PER_LEVEL)
    list = Array(nodes)
    return list if list.size <= limit

    selected = selected_id.present? ? list.find { |n| n.id == selected_id } : nil
    rest = selected ? list.reject { |n| n.id == selected.id } : list
    (selected ? [ selected ] + rest : rest).first(limit)
  end

  def strategy_trail_wire(from_slot, to_slot)
    x1 = from_slot[:left]
    y1 = from_slot[:top]
    x2 = to_slot[:left]
    y2 = to_slot[:top]
    mid_y = (y1 + y2) / 2.0
    format(
      "M%<x1>.1f %<y1>.1f C%<x1>.1f %<m>.1f, %<x2>.1f %<m>.1f, %<x2>.1f %<y2>.1f",
      x1: x1, y1: y1, x2: x2, y2: y2, m: mid_y
    )
  end

  # Completed conquest markers along the mountain story.
  def strategy_completed_flags(goal)
    return [] if goal.blank?

    flags = []
    flags << { kind: "goal", title: goal.title, node: goal } if goal.completed?
    goal.children.select(&:plan?).sort_by(&:position).each do |plan|
      flags << { kind: "plan", title: plan.title, node: plan } if plan.completed?
      plan.children.select(&:project?).sort_by(&:position).each do |project|
        flags << { kind: "project", title: project.title, node: project } if project.completed?
        project.children.select(&:day?).select(&:completed?).sort_by(&:position).each do |battle|
          flags << { kind: "battle", title: battle.title, node: battle }
        end
      end
    end
    flags
  end

  def strategy_breadcrumb_nodes(goal:, plan:, project:, battle:)
    [ goal, plan, project, battle ].compact
  end

  # Objective progress for a Quest Folder card (does not create a host day).
  # Matches Strategy::EnsureFolderQuest host selection (Checklist title, else oldest day).
  def folder_objective_progress(folder)
    days =
      if folder.association(:children).loaded?
        folder.children.select(&:day?).sort_by { |d| [ d.position.to_i, d.id ] }
      else
        folder.children.where(horizon: "day").ordered.to_a
      end
    host = days.find { |d| d.title.to_s == Strategy::EnsureFolderQuest::HOST_TITLE } || days.first
    return { done: 0, total: 0, pct: 0 } if host.blank?

    tasks = host.practice_tasks.to_a
    done = tasks.count(&:completed?)
    total = tasks.size
    pct = total.positive? ? ((done * 100.0) / total).round : 0
    { done: done, total: total, pct: pct }
  end

  # e.g. "7 / 700 pages" for quantified path-level projects.
  def strategy_quantity_progress_label(project)
    return "" unless project&.quantified?

    "#{format_strategy_quantity(project.current_amount)} / #{format_strategy_quantity(project.target_amount)} #{project.unit}"
  end

  def format_strategy_quantity(value)
    n = value.to_d
    return n.to_i.to_s if n == n.to_i

    format("%.1f", n)
  end
end
