# frozen_string_literal: true

module ClimbTogether
  module HighFives
    # Cheer a partner's won battle. One high-five per battle (+ todo) per partner local day.
    class Create
      def self.call(from:, battle:, daily_todo: nil)
        new(from: from, battle: battle, daily_todo: daily_todo).call
      end

      def initialize(from:, battle:, daily_todo: nil)
        @from = from
        @battle = battle
        @daily_todo = daily_todo
      end

      def call
        raise Error, "Battle required" if @battle.blank?

        to = @battle.user
        raise Error, "Not active partners" unless active_partners?(@from, to)
        raise Error, "Battle is not won" unless battle_won?
        raise Error, "Daily todo does not match battle" unless daily_todo_matches?

        zone = Battles::WinsOnLocalDate.time_zone_for(to)
        on = Battles::WinsOnLocalDate.local_today_for(to)
        if HighFive.exists_for_local_day?(
          from_user: @from,
          strategy_goal: @battle,
          daily_todo: @daily_todo,
          on: on,
          time_zone: zone
        )
          raise Error, "Already high-fived this battle today"
        end

        HighFive.create!(
          from_user: @from,
          to_user: to,
          strategy_goal: @battle,
          daily_todo: @daily_todo
        )
      end

      private

      def active_partners?(a, b)
        partner = PartnerFor.call(user: a)
        partner.present? && partner.id == b.id
      end

      def battle_won?
        if @daily_todo
          @daily_todo.completed?
        else
          @battle.completed?
        end
      end

      def daily_todo_matches?
        return true if @daily_todo.nil?

        @daily_todo.strategy_goal_id == @battle.id && @daily_todo.user_id == @battle.user_id
      end
    end
  end
end
