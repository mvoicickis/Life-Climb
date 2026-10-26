# frozen_string_literal: true

module Battles
  # Read-only consecutive local days with ≥1 strategy battle win.
  #
  # Built only from WinsOnLocalDate (one-shot + recurring battles; no Basics,
  # no missions). Soft rule: at most one missed local day is bridged; two
  # missed days end the streak. Differs from Climb::Streak: user local day
  # (not Date.current), battle wins only (not every touch!), always-one-gap
  # soft freeze (no Base Camp token bank), derived (no stored counter).
  class DaysInARow
    # When local today is before created_at (travel_to in tests, rare TZ edges),
    # still look back a year so earlier wins are not dropped by a one-day window.
    LOOKBACK_DAYS = 366

    def self.count(user:)
      new(user:).count
    end

    def initialize(user:)
      @user = user
    end

    def count
      zone_name = WinsOnLocalDate.time_zone_for(@user)
      today = WinsOnLocalDate.local_today_for(@user)
      zone = Time.find_zone!(zone_name)
      created = @user.created_at.in_time_zone(zone).to_date
      from =
        if created > today
          today - LOOKBACK_DAYS
        else
          created
        end

      counts = WinsOnLocalDate.counts_by_date(
        user: @user,
        from: from,
        to: today,
        time_zone: zone_name
      )

      anchor = streak_anchor(today: today, counts: counts)
      return 0 if anchor.nil?

      win_days = 0
      freeze_used = false
      day = anchor

      while day >= from
        if counts[day].to_i.positive?
          win_days += 1
          day -= 1
        elsif win_days.positive? && !freeze_used
          freeze_used = true
          day -= 1
        else
          break
        end
      end

      win_days
    end

    private

    # Newest day that can still keep a streak alive: win today, else yesterday,
    # else today-2 (exactly one missed day before today = soft freeze).
    def streak_anchor(today:, counts:)
      return today if counts[today].to_i.positive?
      return today - 1 if counts[today - 1].to_i.positive?
      return today - 2 if counts[today - 2].to_i.positive?

      nil
    end
  end
end
