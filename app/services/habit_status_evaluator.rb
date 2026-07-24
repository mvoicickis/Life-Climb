# Evaluates a habit's today status from its evaluation method.
# growth  → :better / :same / :worse (vs yesterday)
# standard → :perfect / :too_low / :too_high (vs healthy range)
class HabitStatusEvaluator
  def initialize(habit, on: Date.current)
    @habit = habit
    @date = on
  end

  def call
    habit.growth? ? better_than_yesterday : healthy_range
  end

  def label
    case call
    when :better then "Better than yesterday"
    when :same then "Same as yesterday"
    when :worse then "Worse than yesterday"
    when :perfect then "Within healthy range"
    when :too_low then "Below range"
    when :too_high then "Above range"
    else "—"
    end
  end

  private

  attr_reader :habit, :date

  def better_than_yesterday
    today = habit.amount_or_zero(date)
    yesterday = habit.amount_or_zero(date - 1)

    if today > yesterday
      :better
    elsif today == yesterday
      :same
    else
      :worse
    end
  end

  def healthy_range
    amount = habit.amount_or_zero(date)
    min = habit.min_value
    max = habit.max_value

    return :too_low if min.present? && amount < min
    return :too_high if max.present? && amount > max

    :perfect
  end
end
