# Soft LP decay when a player ignores the game for several days.
class LifePointsDecay
  IDLE_DAYS = 3
  AMOUNT = 5
  SOURCE_TYPE = "LifeDecay"

  def initialize(user)
    @user = user
  end

  def call
    return if @user.total_points <= 0
    return unless idle_long_enough?
    return if decayed_today?

    amount = -[ AMOUNT, @user.total_points ].min
    LifePointsAward.new(@user).award!(
      amount: amount,
      reason: I18n.t("life_points.reasons.decay"),
      source_type: SOURCE_TYPE,
      source_id: Date.current.strftime("%Y%m%d").to_i
    )
  end

  private

  def idle_long_enough?
    last_credit = @user.life_point_ledgers.where("amount > 0").order(created_at: :desc).first
    reference = last_credit&.created_at || @user.created_at
    reference <= IDLE_DAYS.days.ago
  end

  def decayed_today?
    day_key = Date.current.strftime("%Y%m%d").to_i
    @user.life_point_ledgers.where(source_type: SOURCE_TYPE, source_id: day_key).exists?
  end
end
