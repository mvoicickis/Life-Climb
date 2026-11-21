# frozen_string_literal: true

module Today
  # Full-screen "ALL BATTLES WON!" after the last open battle of the local day.
  # Once per local day (users.last_finale_on).
  class FinaleMoment
    Result = Struct.new(
      :battles_today,
      :goal_title,
      :camp_current,
      :camp_total,
      :camp_fill,
      :share_text,
      keyword_init: true
    )

    def self.present_for!(user:, health:, goal_title:, camp:, share_text:)
      new(
        user: user,
        health: health,
        goal_title: goal_title,
        camp: camp,
        share_text: share_text
      ).present!
    end

    def initialize(user:, health:, goal_title:, camp:, share_text:)
      @user = user
      @health = health
      @goal_title = goal_title
      @camp = camp
      @share_text = share_text
    end

    def present!
      return nil if read_only?
      return nil unless @health&.all_clear?
      return nil if @health.total_count.to_i <= 0

      today = Battles::WinsOnLocalDate.local_today_for(@user)
      return nil if @user.last_finale_on == today

      @user.update!(last_finale_on: today)

      Result.new(
        battles_today: @health.done_count.to_i,
        goal_title: @goal_title.to_s,
        camp_current: @camp&.dig(:camp_current).to_i,
        camp_total: @camp&.dig(:camp_count).to_i,
        camp_fill: (@camp&.dig(:percent).to_f / 100.0).clamp(0, 1),
        share_text: @share_text.to_s
      )
    end

    private

    def read_only?
      !@user.has_attribute?(:last_finale_on)
    end
  end
end
