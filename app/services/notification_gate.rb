# frozen_string_literal: true

# Single decision point before WebPush.payload_send — vacation, frequency off,
# win/stuck toggles, and quiet hours. Intensity and cadence throttling live elsewhere.
class NotificationGate
  Result = Struct.new(:allowed, :reason, keyword_init: true) do
    def allowed?
      allowed
    end
  end

  KIND_TRIGGERS = {
    "win" => :win,
    "stuck" => :stuck
  }.freeze

  def self.allow?(user:, kind: nil)
    new(user: user, kind: kind).allow?
  end

  def initialize(user:, kind: nil)
    @user = user
    @kind = kind.to_s.presence
    @preference = user.notification_preference
  end

  def allow?
    return allow! if @preference.nil?

    return deny!(:vacation) if @preference.vacation_active?
    return deny!(:frequency_off) if @preference.frequency == "off"

    # PR5 hook: throttle often / sometimes / rarely here (last-sent / daily caps).
    # This PR only enforces frequency == "off".

    trigger = KIND_TRIGGERS[@kind]
    if trigger == :win && !@preference.win_notifications_enabled?
      return deny!(:trigger_disabled)
    end
    if trigger == :stuck && !@preference.stuck_notifications_enabled?
      return deny!(:trigger_disabled)
    end

    return deny!(:quiet_hours) if in_quiet_hours?

    allow!
  end

  private

  def allow!
    Result.new(allowed: true, reason: nil)
  end

  def deny!(reason)
    Result.new(allowed: false, reason: reason)
  end

  def in_quiet_hours?
    pref = @preference
    return false if pref.time_zone.blank?
    return false if pref.quiet_hours_start.nil? || pref.quiet_hours_end.nil?

    local_hour = Time.current.in_time_zone(pref.time_zone).hour
    start_h = pref.quiet_hours_start
    end_h = pref.quiet_hours_end

    if start_h <= end_h
      local_hour >= start_h && local_hour < end_h
    else
      # Overnight window, e.g. 22 → 7
      local_hour >= start_h || local_hour < end_h
    end
  rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier => e
    Rails.logger.warn("[NotificationGate] quiet_hours fail-open user=#{@user.id} #{e.class}: #{e.message}")
    false
  end
end
