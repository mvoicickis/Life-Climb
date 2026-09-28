# frozen_string_literal: true

module LifePointsHelper
  def stats_week_bar_heights(counts)
    max = counts.map(&:to_i).max.to_i
    return counts.map { 0 } if max <= 0

    counts.map do |count|
      next 0 if count.to_i <= 0

      [ (count.to_f / max * 100).round, 8 ].max
    end
  end

  def stats_calendar_weeks(calendar:, today:, battle_wins:)
    month_start = calendar[:month_start]
    month_end = calendar[:month_end]
    counts = calendar[:counts_by_day]
    leading = (month_start.cwday - 1) % 7
    cells = Array.new(leading)
    month_start.upto(month_end) do |date|
      wins = counts[date].to_i
      cells << {
        date: date,
        wins: wins,
        tier: battle_wins.calendar_tier(wins),
        today: date == today
      }
    end
    trailing = (7 - (cells.size % 7)) % 7
    cells.concat(Array.new(trailing)) if trailing.positive?
    cells.each_slice(7).to_a
  end

  def stats_month_param(date)
    date.strftime("%Y-%m")
  end

  def stats_calendar_nav_url(month_date)
    life_points_path(stats_month: stats_month_param(month_date))
  end

  def stats_more_payload(charts, period)
    period.to_s == "daily" ? charts[:daily] : charts[:weekly]
  end

  def stats_more_card_label(row)
    case row[:key]
    when :battles
      t("progress.stats.more.battles_won")
    when :camps
      t("progress.stats.more.camps_finished")
    when :habit
      if row[:countable]
        t("progress.stats.more.habit_label_amount", name: row[:habit_name], unit: row[:unit])
      else
        t("progress.stats.more.habit_label_days", name: row[:habit_name])
      end
    else
      ""
    end
  end

  def stats_more_display_value(row)
    value = row[:value]
    if row[:key] == :habit && row[:countable]
      formatted = value.to_f == value.to_i ? value.to_i : value.to_f.round(1)
      number_with_delimiter(formatted)
    else
      number_with_delimiter(value.to_i)
    end
  end

  def stats_more_weekday_bar_heights(counts, max)
    max = max.to_i
    max = 1 if max <= 0
    counts.map do |count|
      next 0 if count.to_i <= 0

      [ (count.to_f / max * 100).round, 8 ].max
    end
  end

  def stats_more_line_chart_svg(points, x_labels)
    series = Array(points).map(&:to_f)
    labels = Array(x_labels)
    width = 220
    height = 72
    pad_l = 4
    pad_r = 6
    pad_t = 10
    pad_b = 18
    inner_w = width - pad_l - pad_r
    inner_h = height - pad_t - pad_b
    max = series.max.to_f
    min = series.min.to_f
    span = max - min
    span = 1 if span <= 0
    count = series.length
    pts = series.each_with_index.map do |value, index|
      x = pad_l + (count <= 1 ? 0 : (index.to_f / (count - 1)) * inner_w)
      y = pad_t + inner_h - ((value - min) / span) * inner_h
      [ x, y ]
    end
    line = pts.map { |x, y| format("%.1f,%.1f", x, y) }.join(" ")
    axis_y = format("%.1f", pad_t + inner_h)
    dots_markup = pts.map do |x, y|
      %(<circle cx="#{format("%.1f", x)}" cy="#{format("%.1f", y)}" r="2.5" fill="var(--lp-ink)"/>)
    end.join
    ticks_markup = labels.each_with_index.map do |label, index|
      next if label.blank?

      x = pad_l + (labels.length <= 1 ? 0 : (index.to_f / (labels.length - 1)) * inner_w)
      escaped = ERB::Util.html_escape(label)
      %(<text class="lp-stats-more__axis" x="#{format("%.1f", x)}" y="#{height - 4}" text-anchor="middle">#{escaped}</text>)
    end.compact.join
    markup = <<~SVG
      <svg class="lp-stats-more__chart" viewBox="0 0 #{width} #{height}" aria-hidden="true">
        <line x1="#{pad_l}" y1="#{axis_y}" x2="#{width - pad_r}" y2="#{axis_y}" stroke="var(--lp-border)" stroke-width="1"/>
        <polyline fill="none" stroke="var(--lp-ink)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" points="#{line}"/>
        #{dots_markup}
        #{ticks_markup}
      </svg>
    SVG
    markup.html_safe
  end
end
