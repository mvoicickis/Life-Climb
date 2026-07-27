# frozen_string_literal: true

module StrategyHelper
  CHILD_HORIZON = {
    "goal" => "plan",
    "plan" => "project",
    "project" => "day"
  }.freeze

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

  VISIBLE_PER_LEVEL = 3

  # Percent positions on the trail map (left, top) for absolute card slots.
  SELECTED_PLAN_SLOT = [50, 26].freeze
  PILL_SLOTS = [
    [16, 22], [84, 22], [12, 31], [88, 31], [20, 38], [80, 38], [14, 44], [86, 44]
  ].freeze
  PROJECT_SLOTS = [
    [28, 48], [50, 50], [72, 48]
  ].freeze
  BATTLE_SLOTS = [
    [30, 70], [50, 73], [70, 70]
  ].freeze
  PROJECT_OVERFLOW_SLOT = [88, 52].freeze
  BATTLE_OVERFLOW_SLOT = [88, 74].freeze
  GOAL_SLOT = [50, 10].freeze
  CAMP_SLOT = [22, 90].freeze

  def strategy_trail_slot(kind, index = 0)
    slots =
      case kind.to_s
      when "goal" then [GOAL_SLOT]
      when "plan", "selected_plan" then [SELECTED_PLAN_SLOT]
      when "pill" then PILL_SLOTS
      when "project" then PROJECT_SLOTS
      when "battle", "day" then BATTLE_SLOTS
      when "project_overflow" then [PROJECT_OVERFLOW_SLOT]
      when "battle_overflow" then [BATTLE_OVERFLOW_SLOT]
      when "camp" then [CAMP_SLOT]
      else [[50, 50]]
      end
    left, top = slots[[index, slots.length - 1].min]
    { left: left, top: top }
  end

  def strategy_visible_nodes(nodes, selected_id = nil, limit: VISIBLE_PER_LEVEL)
    list = Array(nodes)
    return list if list.size <= limit

    selected = selected_id.present? ? list.find { |n| n.id == selected_id } : nil
    rest = selected ? list.reject { |n| n.id == selected.id } : list
    (selected ? [selected] + rest : rest).first(limit)
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
end
