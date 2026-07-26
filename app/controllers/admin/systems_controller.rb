# frozen_string_literal: true

module Admin
  class SystemsController < BaseController
    def show
      @ruby_version = RUBY_VERSION
      @rails_version = Rails.version
      @environment = Rails.env
      @database = ActiveRecord::Base.connection.adapter_name
      @git_sha = ENV["RENDER_GIT_COMMIT"].presence || ENV["GIT_SHA"].presence || read_revision_file
      @record_counts = {
        users: User.count,
        journeys: LifeJourney.count,
        strategy_goals: StrategyGoal.count,
        missions: Mission.count,
        daily_todos: DailyTodo.count,
        feedbacks: Feedback.count,
        sessions: Session.count,
        ledgers: LifePointLedger.count,
        app_settings: AppSetting.table_available? ? AppSetting.count : 0
      }
      @boot_time = Rails.application.config.x.booted_at
      @uptime_hint = uptime_from_boot || process_uptime_hint
    end

    private

    def read_revision_file
      path = Rails.root.join("REVISION")
      File.exist?(path) ? File.read(path).strip.presence : nil
    rescue StandardError
      nil
    end

    def uptime_from_boot
      started = Rails.application.config.x.booted_at
      return nil unless started

      format_duration(Time.current - started)
    end

    def process_uptime_hint
      started = File.stat("/proc/1").ctime rescue nil
      return nil unless started

      format_duration(Time.current - started)
    rescue StandardError
      nil
    end

    def format_duration(seconds)
      total = seconds.to_i
      hours = total / 3600
      mins = (total % 3600) / 60
      "#{hours}h #{mins}m"
    end
  end
end
