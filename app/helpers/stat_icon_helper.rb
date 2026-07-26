module StatIconHelper
  # Lightweight emoji icons for Today cards — inferred from name/unit.
  def stat_icon_for(habit)
    name = habit.name.to_s.downcase
    unit = habit.unit.to_s.downcase

    return "🚶" if unit.match?(/step/) || name.match?(/walk|step|run|jog|comm/)
    return "📚" if unit.match?(/page|chapter|book/) || name.match?(/read|page|book|ruby|study|pdc/)
    return "💪" if unit.match?(/rep|push|pull|squat/) || name.match?(/push.?up|pull.?up|squat|workout|gym|lift|exercise/)
    return "🧘" if name.match?(/meditat|breath|yoga|calm/)
    return "💧" if unit.match?(/glass|liter|litre|ml|oz/) || name.match?(/water|hydrat/)
    return "😴" if name.match?(/sleep|rest|bed/)
    return "📝" if name.match?(/journal|writ|note|diary|postulate|process/)
    return "👥" if name.match?(/people|comm|social|network/)
    return "🥗" if name.match?(/meal|eat|food|nutrition|calorie|veg|fruit|healthy/)
    return "📱" if name.match?(/screen|phone|social/)
    return "🇩🇪" if name.include?("german")
    return "🧠" if unit.match?(/min|hour/) && name.match?(/study|learn|lesson|language|vocab|spanish|french/)
    return "⏱️" if unit.match?(/min|hour/)
    "✨"
  end

  def amount_delta_for(habit)
    habit.today_amount - habit.yesterday_amount
  end

  def amount_delta_label(habit)
    delta = amount_delta_for(habit)
    unit = habit.unit

    if habit.healthy_range?
      return t("deltas.in_range") if habit.status == :perfect
      return t("deltas.below_range") if habit.status == :too_low
      return t("deltas.above_range") if habit.status == :too_high
    end

    return t("deltas.same") if delta.zero?

    sign = delta.positive? ? "+" : ""
    t("deltas.vs_yesterday", signed: "#{sign}#{format_amount(delta)}", unit: unit)
  end

  def share_worthy?(habit, streak: 0)
    insights = DashboardInsights.new(habit.user, trackers: [ habit ])
    return true if insights.personal_record?(habit)
    return true if insights.big_boost?(habit)

    false
  end
end
