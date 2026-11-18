# frozen_string_literal: true

module ClimbTogether
  # Side-by-side mountain cards for an active rope team.
  # Wins + camp progress only — never open battles or misses.
  class SideBySide
    Card = Struct.new(
      :user,
      :name,
      :journey,
      :camp_of,
      :camp_name,
      :picking_mountain,
      :wins_this_week,
      keyword_init: true
    )

    Result = Struct.new(:you, :partner, keyword_init: true)

    def self.call(viewer:)
      new(viewer: viewer).call
    end

    def initialize(viewer:)
      @viewer = viewer
    end

    def call
      partner = PartnerFor.call(user: @viewer)
      return nil if partner.blank?

      Result.new(
        you: card_for(user: @viewer, you: true),
        partner: card_for(user: partner, you: false)
      )
    end

    private

    def card_for(user:, you:)
      name = you ? I18n.t("climb_together.side.you") : user.display_name
      wins = Stats::BattleWins.call(user: user).this_week[:total].to_i
      journey = Goals::Current.journey_for(user: user)
      goal = Goals::Current.goal_for(user: user, journey: journey)

      if goal.blank?
        return Card.new(
          user: user,
          name: name,
          journey: nil,
          camp_of: nil,
          camp_name: nil,
          picking_mountain: true,
          wins_this_week: wins
        )
      end

      camps = path_camps_for(goal)
      if camps.empty?
        return Card.new(
          user: user,
          name: name,
          journey: journey,
          camp_of: nil,
          camp_name: nil,
          picking_mountain: true,
          wins_this_week: wins
        )
      end

      completed = camps.count(&:completed?)
      total = camps.size
      current = [ completed + 1, total ].min
      camp = Strategy::PathProject.resolve(user: user, journey: journey)

      Card.new(
        user: user,
        name: name,
        journey: journey,
        camp_of: I18n.t("climb_together.side.camp_of", current: current, total: total),
        camp_name: camp&.title.to_s.presence,
        picking_mountain: false,
        wins_this_week: wins
      )
    end

    def path_camps_for(goal)
      plans = goal.children.for_kind("plan").not_holding.ordered.includes(:children)
      plans.flat_map do |plan|
        plan.children.select { |child| child.project? && !child.holding? }
      end
    end
  end
end
