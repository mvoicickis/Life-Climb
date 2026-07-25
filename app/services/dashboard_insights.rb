# Computes Today-board extras: streak, weekly score series, focus tips, milestones.
class DashboardInsights
  GOOD = %i[better perfect].freeze
  STREAK_MILESTONES = [ 7, 30, 100 ].freeze

  def initialize(user, trackers:)
    @user = user
    @trackers = Array(trackers)
  end

  def streak_days
    return 0 if @user.daily_logs.none?

    cursor = @user.daily_logs.exists?(logged_on: Date.current) ? Date.current : Date.yesterday
    count = 0

    while logged_on?(cursor)
      count += 1
      cursor -= 1
    end

    count
  end

  # Rolling last 7 days (including today): overall daily score 0–100.
  def week_series
    (6.downto(0)).map do |ago|
      day = Date.current - ago
      {
        date: day,
        label: I18n.l(day, format: :chart_day, default: day.strftime("%a")),
        full_label: I18n.l(day, format: :long, default: day.strftime("%b %-d")),
        percent: day_score(day),
        current: day == Date.current,
        future: false
      }
    end
  end

  def week_percent
    days = week_series
    return 0 if days.empty?

    (days.sum { |point| point[:percent] } / days.size.to_f).round
  end

  def focus_tips
    tips = prioritized_trackers.filter_map { |tracker| tip_for(tracker) }
    tips.first(3).presence || default_tips
  end

  # Needs-work first, then same, then good — largest gap wins within a status.
  def prioritized_trackers
    @trackers.sort_by { |tracker| [ status_rank(tracker.status), -attention_gap(tracker), tracker.position ] }
  end

  def celebrations
    items = []

    if STREAK_MILESTONES.include?(streak_days)
      items << {
        kind: :streak,
        label: I18n.t("habits.milestone_streak", count: streak_days),
        tracker: nil
      }
    end

    @trackers.each do |tracker|
      if personal_record?(tracker)
        items << { kind: :record, label: I18n.t("habits.milestone_record"), tracker: tracker }
      elsif big_boost?(tracker)
        items << { kind: :boost, label: I18n.t("habits.milestone_boost"), tracker: tracker }
      end
    end

    items.first(2)
  end

  def personal_record?(habit)
    today = habit.today_amount
    return false if today <= 0

    prior_max = habit.daily_logs.where("logged_on < ?", Date.current).maximum(:amount)
    prior_max = BigDecimal("0") if prior_max.blank?
    today > prior_max
  end

  def big_boost?(habit)
    return false unless habit.status == :better

    delta = habit.today_amount - habit.yesterday_amount
    return false if delta <= 0

    threshold = [ habit.yesterday_amount * BigDecimal("0.25"), BigDecimal("1") ].max
    delta >= threshold
  end

  private

  def status_rank(status)
    case status
    when :worse then 0
    when :too_low, :too_high then 1
    when :same then 2
    when :better, :perfect then 3
    else 4
    end
  end

  def attention_gap(tracker)
    case tracker.status
    when :worse
      [ tracker.yesterday_amount - tracker.today_amount, 0 ].max.to_f
    when :too_low
      return 0 if tracker.min_value.blank?

      [ tracker.min_value - tracker.today_amount, 0 ].max.to_f
    when :too_high
      return 0 if tracker.max_value.blank?

      [ tracker.today_amount - tracker.max_value, 0 ].max.to_f
    else
      0
    end
  end

  def logged_on?(date)
    @user.daily_logs.exists?(logged_on: date)
  end

  def day_score(date)
    return 0 if @trackers.empty?

    good = @trackers.count { |tracker| GOOD.include?(HabitStatusEvaluator.new(tracker, on: date).call) }
    ((good / @trackers.size.to_f) * 100).round
  end

  def tip_for(tracker)
    status = tracker.status
    name = tracker.name.to_s.strip
    key = "#{name} #{tracker.unit}".downcase

    case status
    when :worse
      needed = tracker.yesterday_amount - tracker.today_amount
      needed = needed.ceil
      needed = 1 if needed < 1
      amount = format_amount(needed)

      if key.match?(/walk|step|soļ|soli|schritt|paso/)
        I18n.t("focus_tips.walk_more", amount: amount)
      elsif key.match?(/read|page|book|lappus|grāmat|seite|página|pagina|libro/)
        I18n.t("focus_tips.read_more", amount: amount)
      else
        I18n.t("focus_tips.do_more", amount: amount, name: name)
      end
    when :too_low
      I18n.t("focus_tips.lift_low", name: name, amount: format_amount(tracker.min_value))
    when :too_high
      I18n.t("focus_tips.ease_high", name: name, amount: format_amount(tracker.max_value))
    end
  end

  def default_tips
    [
      I18n.t("focus_tips.default_one"),
      I18n.t("focus_tips.default_two"),
      I18n.t("focus_tips.default_three")
    ]
  end

  def format_amount(amount)
    amount = 0 if amount.blank?
    amount == amount.to_i ? amount.to_i.to_s : amount.to_s("F")
  end
end
