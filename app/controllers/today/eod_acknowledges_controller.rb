# frozen_string_literal: true

module Today
  # Step 1 → 2: user tapped through the win moment.
  class EodAcknowledgesController < ApplicationController
    include Dashboard::TodaySurface

    def create
      @journey = current_user.primary_focused_journey
      unless @journey
        redirect_to dashboard_path, status: :see_other
        return
      end

      assign_today_battle_surface!(reconcile: false)
      habits_on = habits_local_day
      @battlefield_health = Today::BattlefieldHealth.call(
        open_count: @battle_open_count,
        total_count: @battle_total_count,
        habits: @habits,
        habits_on: habits_on
      )
      habits_gate = GameRules.habits_enabled?
      ready = Today::EndOfDay.ready?(
        health: @battlefield_health,
        habits: @habits,
        habits_gate_enabled: habits_gate,
        habits_on: habits_on
      )

      unless ready
        redirect_to dashboard_path, status: :see_other
        return
      end

      EodFlow.acknowledge!(session)
      redirect_to dashboard_path, status: :see_other
    end
  end
end
