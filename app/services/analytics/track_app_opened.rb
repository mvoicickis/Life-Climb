# frozen_string_literal: true

module Analytics
  # Record at most one app_opened event per user per local calendar day.
  class TrackAppOpened
    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      zone_name = Battles::WinsOnLocalDate.time_zone_for(@user)
      zone = time_zone(zone_name)
      local_date = Time.current.in_time_zone(zone).to_date
      next_open_at = next_local_midnight(zone, local_date)

      event_created = false

      ActiveRecord::Base.transaction do
        updated = User.where(id: @user.id)
                      .where("last_opened_on IS DISTINCT FROM ?", local_date)
                      .update_all(last_opened_on: local_date, next_app_open_at: next_open_at, updated_at: Time.current)

        if updated == 1
          @user.user_events.create!(
            name: "app_opened",
            properties: { "local_date" => local_date.iso8601, "time_zone" => zone_name }
          )
          event_created = true
        else
          refresh_stale_next_open_at!(local_date, next_open_at)
        end
      end

      event_created
    end

    private

    def time_zone(zone_name)
      Time.find_zone!(zone_name)
    rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier
      Time.find_zone!("UTC")
    end

    def next_local_midnight(zone, local_date)
      zone.local(local_date.year, local_date.month, local_date.day).next_day.beginning_of_day
    end

    def refresh_stale_next_open_at!(local_date, next_open_at)
      row = User.where(id: @user.id).pick(:last_opened_on, :next_app_open_at)
      return if row.blank?

      current_date, current_next = row
      return unless current_date == local_date
      return if current_next == next_open_at

      User.where(id: @user.id, last_opened_on: local_date).update_all(
        next_app_open_at: next_open_at,
        updated_at: Time.current
      )
    end
  end
end
