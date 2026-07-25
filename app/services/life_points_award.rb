# Weighted LifePoints: creation >> completion (ratios from product plan).
class LifePointsAward
  ACTION = 10
  DAY_COMPLETE = 30
  BUILDING_SHIP = 250
  FINISHED_PRODUCT = 1000
  RHYTHM = 5

  def initialize(user)
    @user = user
  end

  def award!(amount:, reason:, source: nil, source_type: nil, source_id: nil)
    amount = amount.to_i
    return if amount.zero?

    ActiveRecord::Base.transaction do
      attrs = {
        amount: amount,
        reason: reason
      }
      if source
        attrs[:source] = source
      else
        attrs[:source_type] = source_type
        attrs[:source_id] = source_id
      end

      entry = @user.life_point_ledgers.create!(attrs)
      @user.increment!(:total_points, amount)
      entry
    end
  end

  def for_action!(action)
    award!(
      amount: ACTION,
      reason: I18n.t("life_points.reasons.action", title: action.title),
      source: action
    )
    maybe_day_bonus!(action.scheduled_on)
  end

  def for_building_ship!(building)
    award!(
      amount: BUILDING_SHIP,
      reason: I18n.t("life_points.reasons.building", title: building.title),
      source: building
    )
  end

  def for_finished_product!(product)
    award!(
      amount: FINISHED_PRODUCT,
      reason: I18n.t("life_points.reasons.finished", title: product.title),
      source: product
    )
  end

  def for_rhythm!(habit)
    award!(
      amount: RHYTHM,
      reason: I18n.t("life_points.reasons.rhythm", title: habit.name),
      source: habit
    )
  end

  private

  def maybe_day_bonus!(day)
    todays = @user.today_actions.for_day(day)
    return if todays.empty?
    return unless todays.incomplete.none?

    day_key = day.strftime("%Y%m%d").to_i
    return if @user.life_point_ledgers.where(source_type: "DayComplete", source_id: day_key).exists?

    award!(
      amount: DAY_COMPLETE,
      reason: I18n.t("life_points.reasons.day", day: I18n.l(day)),
      source_type: "DayComplete",
      source_id: day_key
    )
  end
end
