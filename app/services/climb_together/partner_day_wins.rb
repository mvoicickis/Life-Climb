# frozen_string_literal: true

module ClimbTogether
  # Partner's battle wins on their local day — for the Today partner row + high-five.
  class PartnerDayWins
    Result = Struct.new(:partner, :count, :battle, :daily_todo, :cheered, keyword_init: true)

    def self.call(viewer:)
      new(viewer: viewer).call
    end

    def initialize(viewer:)
      @viewer = viewer
    end

    def call
      partner = PartnerFor.call(user: @viewer)
      return nil unless partner

      zone_name = Battles::WinsOnLocalDate.time_zone_for(partner)
      on = Battles::WinsOnLocalDate.local_today_for(partner)
      zone = Time.find_zone!(zone_name)
      range_start = zone.local(on.year, on.month, on.day).beginning_of_day
      range_end = zone.local(on.year, on.month, on.day).end_of_day

      one_shots = Battles::WinsOnLocalDate.one_shot_battles_completed_in_range(
        user: partner,
        range_start: range_start,
        range_end: range_end
      ).to_a

      todos = Battles::WinsOnLocalDate.recurring_strategy_todos_in_date_range(
        user: partner,
        from: on,
        to: on
      ).includes(:strategy_goal).to_a

      battle, daily_todo = latest_win(one_shots, todos)
      cheered = HighFive.exists_for_partner_day?(
        from_user: @viewer,
        to_user: partner,
        on: on,
        time_zone: zone_name
      )

      Result.new(
        partner: partner,
        count: one_shots.size + todos.size,
        battle: battle,
        daily_todo: daily_todo,
        cheered: cheered
      )
    end

    private

    def latest_win(one_shots, todos)
      latest_at = nil
      battle = nil
      daily_todo = nil

      one_shots.each do |shot|
        at = shot.completed_at
        next if at.blank?
        next if latest_at && at <= latest_at

        latest_at = at
        battle = shot
        daily_todo = nil
      end

      todos.each do |todo|
        at = todo.completed_at
        next if at.blank?
        next if latest_at && at <= latest_at

        latest_at = at
        battle = todo.strategy_goal
        daily_todo = todo
      end

      [ battle, daily_todo ]
    end
  end
end
