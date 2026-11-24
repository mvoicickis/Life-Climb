# frozen_string_literal: true

module FirstTips
  module Assign
    extend ActiveSupport::Concern

    private

    def assign_first_tip_for_today!
      assign_first_tip!(
        page: :today,
        open_battle_count: @battle_open_count.to_i,
        streak_moment: @streak_moment.present?,
        climb_reward: flash[:climb_reward].present?,
        plan_route: @show_plan_route == true
      )
    end

    def assign_first_tip_for_mountain!
      journey = @journey || current_user.primary_focused_journey
      assign_first_tip!(
        page: :mountain,
        first_camp_reveal: journey&.first_camp_reveal_pending? == true,
        base_camp_intro: current_user.needs_base_camp_intro?
      )
    end

    def assign_first_tip_for_you!
      assign_first_tip!(page: :you)
    end

    def assign_first_tip!(page:, open_battle_count: 0, streak_moment: false,
                          climb_reward: false, plan_route: false,
                          first_camp_reveal: false, base_camp_intro: false)
      if read_only_impersonation?
        @first_tip = nil
        return
      end

      context = FirstTips::Context.new(
        page: page,
        open_battle_count: open_battle_count,
        read_only_impersonation: false,
        streak_moment: streak_moment,
        climb_reward: climb_reward,
        plan_route: plan_route,
        first_camp_reveal: first_camp_reveal,
        base_camp_intro: base_camp_intro
      )
      @first_tip = FirstTips.next_tip_for(user: current_user, page: page, context: context)
    end
  end
end
