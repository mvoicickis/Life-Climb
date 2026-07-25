# Computes Today-board extras: streak, weekly score series, and focus tips.
class DashboardInsights
  GOOD = %i[better perfect].freeze

  def initialize(user, trackers:)
    @user = user
    @trackers = Array(trackers)
  end

  # Consecutive calendar days with at least one log, ending today or yesterday.
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

  # Mon–Sun of the current week: percent of home trackers in a "good" state that day.
  def week_series
    week_start = Date.current.beginning_of_week(:monday)

    (0..6).map do |offset|
      day = week_start + offset
      {
        date: day,
        label: day.strftime("%a")[0, 2],
        percent: day_score(day),
        current: day == Date.current,
        future: day > Date.current
      }
    end
  end

  def week_percent
    days = week_series.reject { |point| point[:future] }
    return 0 if days.empty?

    (days.sum { |point| point[:percent] } / days.size.to_f).round
  end

  def focus_tips
    tips = @trackers.filter_map { |tracker| tip_for(tracker) }
    tips.first(3).presence || default_tips
  end

  private

  def logged_on?(date)
    @user.daily_logs.exists?(logged_on: date)
  end

  def day_score(date)
    return 0 if @trackers.empty?
    return 0 if date > Date.current

    good = @trackers.count { |tracker| GOOD.include?(HabitStatusEvaluator.new(tracker, on: date).call) }
    ((good / @trackers.size.to_f) * 100).round
  end

  def tip_for(tracker)
    status = tracker.status
    return nil if GOOD.include?(status) || status == :same

    case status
    when :worse
      "Lift #{tracker.name} above yesterday’s #{format_amount(tracker.yesterday_amount)} #{tracker.unit}."
    when :too_low
      min = tracker.min_value
      "Bring #{tracker.name} up toward #{format_amount(min)} #{tracker.unit}."
    when :too_high
      max = tracker.max_value
      "Ease #{tracker.name} back under #{format_amount(max)} #{tracker.unit}."
    end
  end

  def default_tips
    [
      "Log what matters today — even a small number counts.",
      "Pick one thing to beat yesterday.",
      "Keep Tomorrow simple: one clear win."
    ]
  end

  def format_amount(amount)
    amount = 0 if amount.blank?
    amount == amount.to_i ? amount.to_i.to_s : amount.to_s("F")
  end
end
