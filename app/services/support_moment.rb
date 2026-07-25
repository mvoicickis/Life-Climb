# Soft thank-you moments after meaningful milestones — never on Today, never repeated.
class SupportMoment
  MILESTONES = %i[
    first_finished_product
    life_points_100
    days_invested_30
    year_with_lifepoints
  ].freeze

  def initialize(user)
    @user = user
  end

  def muted?
    @user.support_prompts_muted?
  end

  def eligible
    return nil if muted?

    shown = Array(@user.support_milestones_shown).map(&:to_s)
    MILESTONES.each do |key|
      next if shown.include?(key.to_s)
      return key if met?(key)
    end
    nil
  end

  def mark_shown!(key)
    shown = Array(@user.support_milestones_shown).map(&:to_s)
    shown << key.to_s unless shown.include?(key.to_s)
    @user.update!(support_milestones_shown: shown)
  end

  def mute!
    @user.update!(support_prompts_muted: true)
  end

  private

  def met?(key)
    case key.to_sym
    when :first_finished_product
      @user.finished_products.count >= 1
    when :life_points_100
      @user.life_points >= 100
    when :days_invested_30
      @user.days_invested >= 30
    when :year_with_lifepoints
      @user.created_at <= 1.year.ago
    else
      false
    end
  end
end
