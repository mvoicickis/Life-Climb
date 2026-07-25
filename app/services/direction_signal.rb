# Simple status: are you going the right way on today's focus?
class DirectionSignal
  STATUSES = %w[on_track getting_started off_track].freeze

  def initialize(user:, building:, actions:, life_area: nil)
    @user = user
    @building = building
    @actions = Array(actions)
    @life_area = life_area
  end

  def status
    return "getting_started" if @building.blank?
    return "getting_started" if @actions.empty? && recent_lp.zero?

    done_today = @actions.any?(&:completed?)
    lp_today = points_awarded_today?

    if done_today || lp_today
      "on_track"
    elsif @actions.any?
      "getting_started"
    elsif recent_lp.zero?
      "off_track"
    else
      "getting_started"
    end
  end

  def title
    I18n.t("direction.#{status}.title")
  end

  def body
    part = @life_area&.short_label || @building&.goal&.title
    I18n.t("direction.#{status}.body", part: part)
  end

  def harmony_hint
    return if @life_area.blank?

    dream = @life_area.dream
    others = dream.life_areas.filled.ordered.reject { |area| area.id == @life_area.id }
    return if others.empty?

    names = others.first(2).map(&:short_label).to_sentence
    I18n.t("direction.harmony", others: names, focus: @life_area.short_label)
  end

  private

  def points_awarded_today?
    @user.life_point_ledgers.where("created_at >= ?", Time.zone.now.beginning_of_day).exists?
  end

  def recent_lp
    @user.life_point_ledgers.where("created_at >= ?", 3.days.ago).sum(:amount)
  end
end
