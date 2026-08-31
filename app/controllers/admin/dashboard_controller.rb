# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def show
      @metrics = Admin::Metrics.call
      @cards = @metrics[:cards]
      @charts = @metrics[:charts]
      @excluded_users_count = @metrics[:excluded_users]
      @recent_users = @metrics[:recent_users]
      @recent_feedbacks = @metrics[:recent_feedbacks]
      @recent_ledgers = @metrics[:recent_ledgers]

      @funnel_sort = funnel_sort_param
      @funnel_filter = params[:filter].presence
      @funnel = Admin::UserFunnel.call(sort: @funnel_sort, filter: @funnel_filter)
      @onboarding_step_funnel = Admin::OnboardingStepFunnel.call
      @cards = @cards.merge(returned_users: @funnel[:stage_counts][:returned_second_day])
    end

    private

    def funnel_sort_param
      sort = params[:sort].to_s
      %w[last_seen last_seen_asc].include?(sort) ? sort : "last_seen"
    end
  end
end
