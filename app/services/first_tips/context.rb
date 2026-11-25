# frozen_string_literal: true

module FirstTips
  # Server-side inputs for whether a tip may be offered on this page load.
  class Context
    attr_reader :page, :open_battle_count, :read_only_impersonation,
                :streak_moment, :climb_reward, :first_camp_reveal, :plan_route

    def initialize(
      page:,
      open_battle_count: 0,
      read_only_impersonation: false,
      streak_moment: false,
      climb_reward: false,
      first_camp_reveal: false,
      plan_route: false
    )
      @page = page.to_sym
      @open_battle_count = open_battle_count.to_i
      @read_only_impersonation = read_only_impersonation
      @streak_moment = streak_moment
      @climb_reward = climb_reward
      @first_camp_reveal = first_camp_reveal
      @plan_route = plan_route
    end

    def open_battles?
      open_battle_count.positive?
    end

    def blocked_by_overlays?
      streak_moment || climb_reward || first_camp_reveal || plan_route
    end
  end
end
