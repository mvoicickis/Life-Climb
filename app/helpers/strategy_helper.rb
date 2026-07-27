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
end
