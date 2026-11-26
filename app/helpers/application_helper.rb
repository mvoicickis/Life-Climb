module ApplicationHelper
  # Global habits UI (settings, commitment copy, legacy Today surface).
  # Developers always see habits; everyone else follows GameRules.
  def habits_enabled?
    return true if current_user&.developer?

    GameRules.habits_enabled?
  end

  def needs_browser_time_zone_capture?
    return false unless current_user

    pref = current_user.notification_preference
    pref.nil? || pref.time_zone.blank?
  end

  # Skip rendering when no companion is chosen yet (nil character_image).
  def companion_image_tag(user = current_user, **options)
    return if user.blank? || user.character_image.blank?

    image_tag user.character_image, **options
  end

  # Today hero moments: You profile animal → mountain companion → default bird.
  def hero_animal_image_path(user)
    return "avatars/bird.webp" if user.blank?

    user.avatar_image.presence || user.character_image.presence || "avatars/bird.webp"
  end

  # Camp pill colors for Today V2 battlefield rows.
  def battlefield_camp_style(project)
    hex = if project&.trail_accent_hex.present?
      project.trail_accent_hex
    else
      MountainTrailHelper::ACCENT_HEX.fetch(project&.tagged_color_key.to_s, "#57534e")
    end
    { color: hex, bg: "#{hex}26" }
  end

  def battlefield_hp_band_class(band)
    case band.to_sym
    when :safe then "is-safe"
    when :warn then "is-warn"
    when :neutral then "is-neutral"
    else "is-danger"
    end
  end

  # Stage label (e.g. "Camp set") lives on the mountain caption only —
  # never echo mountain[:label] here or the hero shows it twice.
  def dash_momentum_line(percent, mountain: nil)
    p = percent.to_i
    key =
      if p >= 100 then "summit"
      elsif p >= 85 then "final"
      elsif p >= 70 then "close"
      elsif p >= 40 then "halfway"
      elsif p >= 10 then "climbing"
      else "begun"
      end
    I18n.t("dash.momentum.#{key}")
  end

  def area_copy(area_or_key, key, **options)
    area_key =
      case area_or_key
      when LifeArea then area_or_key.key
      when String, Symbol then area_or_key
      else area_or_key.to_s
      end
    AreaCopy.for(area_key, key, **options)
  end

  CANONICAL_HOST = CanonicalHost::CANONICAL_HOST
  LEGACY_RENDER_HOST_SUFFIX = ".onrender.com"

  def show_legacy_host_banner?
    request.host.to_s.end_with?(LEGACY_RENDER_HOST_SUFFIX)
  end

  def canonical_base_url
    CanonicalHost.base_url
  end

  def social_meta_description
    "The mountain is yours to climb"
  end

  def social_meta_title
    "Life Climb — #{social_meta_description}"
  end

  def social_share_title
    content_for?(:social_title) ? content_for(:social_title) : social_meta_title
  end

  def social_share_description
    content_for?(:social_description) ? content_for(:social_description) : page_meta_description
  end

  def social_og_image_path
    "/og-lifeclimb-share.png"
  end

  def social_share_image_url
    content_for?(:social_image) ? content_for(:social_image) : absolute_url(social_og_image_path)
  end

  def social_share_image_type
    content_for?(:social_image_type) ? content_for(:social_image_type) : "image/png"
  end

  def social_share_image_width
    content_for?(:social_image_width) ? content_for(:social_image_width) : "1200"
  end

  def social_share_image_height
    content_for?(:social_image_height) ? content_for(:social_image_height) : "630"
  end

  def social_share_image_alt
    content_for?(:social_image_alt) ? content_for(:social_image_alt) : "Life Climb — #{social_meta_description}"
  end

  def social_share_type
    content_for?(:social_type) ? content_for(:social_type) : "website"
  end

  def absolute_url(path)
    "#{canonical_base_url}#{path}"
  end

  # Fresh share URL so WhatsApp re-scrapes OG preview (it caches the bare homepage).
  def share_landing_url
    absolute_url("/?s=lp")
  end

  def referral_share_url(user = current_user)
    ReferralShareUrl.for(user, base_url: canonical_base_url)
  end

  def app_version
    APP_VERSION
  end

  def page_meta_title
    content_for?(:title) ? content_for(:title) : "Life Climb"
  end

  def page_meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : I18n.t("landing.meta_description")
  end

  # App chrome theme: always light (appearance picker removed; dark tokens kept in CSS).
  def theme_for_request
    "light"
  end

  def theme_color_for_request
    theme_for_request == "dark" ? "#0b0f14" : "#f8fafc"
  end

  def status_tone(status)
    case status
    when :better, :perfect then :good
    when :same then :same
    else :bad
    end
  end

  def vs_yesterday_classes(status)
    case status_tone(status)
    when :good
      "today-card today-card--good"
    when :same
      "today-card today-card--same"
    else
      "today-card today-card--off"
    end
  end

  def vs_yesterday_bar_class(status)
    case status_tone(status)
    when :good then "bg-emerald-400"
    when :same then "bg-amber-300"
    else "bg-rose-400"
    end
  end

  def vs_yesterday_badge_class(status)
    case status_tone(status)
    when :good then "bg-emerald-500/20 text-emerald-300 ring-1 ring-emerald-400/30"
    when :same then "bg-amber-400/15 text-amber-200 ring-1 ring-amber-300/30"
    else "bg-rose-500/20 text-rose-300 ring-1 ring-rose-400/30"
    end
  end

  def status_emoji(status)
    case status_tone(status)
    when :good then "🟢"
    when :same then "🟡"
    else "🔴"
    end
  end

  def status_badge_text(status)
    case status
    when :better then t("status.better")
    when :same then t("status.same")
    when :worse then t("status.worse")
    when :perfect then t("status.perfect")
    when :too_low then t("status.too_low")
    when :too_high then t("status.too_high")
    else status.to_s.humanize
    end
  end

  def vs_yesterday_short(status)
    "#{status_emoji(status)} #{status_badge_text(status)}"
  end

  def status_full_text(status)
    case status
    when :better then "🟢 #{t('status.better_full')}"
    when :same then "🟡 #{t('status.same_full')}"
    when :worse then "🔴 #{t('status.worse_full')}"
    when :perfect then "🟢 #{t('status.perfect_full')}"
    when :too_low then "🔴 #{t('status.too_low_full')}"
    when :too_high then "🔴 #{t('status.too_high_full')}"
    else status.to_s.humanize
    end
  end

  def share_message_for(tracker)
    ShareMessageBuilder.new(tracker, landing_url: share_landing_url).call
  end

  def share_message_body_for(tracker)
    ShareMessageBuilder.new(tracker, landing_url: share_landing_url).body
  end

  def invite_share_message
    InviteShareMessage.call(landing_url: referral_share_url)
  end

  def invite_share_message_body
    InviteShareMessage.body(landing_url: referral_share_url)
  end

  # Accepts Numeric or string (e.g. session undo snapshots store decimals as text).
  def format_amount(amount)
    return "0" if amount.blank?

    number = amount.is_a?(Numeric) ? amount.to_d : BigDecimal(amount.to_s)
    number == number.to_i ? number.to_i.to_s : number.to_s("F")
  rescue ArgumentError
    "0"
  end

  # Server-side undo snapshot after additive habit log (not client-forgeable).
  def habit_today_amount_context(habit, on: current_user.local_today)
    amount = habit.today_amount(on: on)
    target = habit.stretch_goal? ? habit.todays_goal_value(on: on) : nil
    progress = habit.goal_progress_percent(on: on)
    over = progress.is_a?(Numeric) && progress > 100
    hit = progress.is_a?(Numeric) && progress >= 100
    done = habit.completed_today?(on: on)
    show_pct = (progress.is_a?(Numeric) && habit.quantity_checkin? && habit.stretch_goal?) ||
               (habit.binary_checkin? && done)
    {
      amount: amount,
      target: target,
      progress: progress,
      over: over,
      hit: hit,
      done: done,
      show_pct: show_pct
    }
  end

  # Mirrored in basic_today_save_queue.js (habitTodayRowState) — change both.
  def habit_today_row_state(habit)
    ctx = habit_today_amount_context(habit)
    tokens = []
    tokens << "is-done" if ctx[:done] || habit.met_habit_goal?
    tokens << "is-over" if ctx[:over]
    tokens << "is-hit" if ctx[:hit] && !ctx[:over]
    tokens.compact.join(" ")
  end

  def basics_survived_count(habits, on: current_user.local_today)
    list = Array(habits)
    done_n = list.count { |habit| habit.survived_today?(on) }
    { done_n: done_n, total: list.size }
  end

  def habit_log_undo_for(habit, on: current_user.local_today)
    bag = session[DailyLogsController::UNDO_SESSION_KEY]
    return nil unless bag.is_a?(Hash)

    entry = bag.stringify_keys[habit.id.to_s]
    return nil unless entry.is_a?(Hash)
    return nil unless entry["on"] == on.iso8601

    entry
  end

  def habit_progress_bar_width(progress)
    return 0 if progress.nil?

    [ progress.to_i, 100 ].min
  end

  # Discrete notches for RPG progress bars (hero 10, habit 12).
  # Mirrored in basic_today_save_queue.js (habitProgressSegments) — change both.
  def habit_progress_segments(percent, count:)
    p = percent.nil? ? 0 : percent.to_i
    over = p > 100
    capped = [ p, 100 ].min
    Array.new(count) do |i|
      threshold = ((i + 1) * 100.0 / count)
      if capped >= threshold
        over ? "o" : "f"
      else
        ""
      end
    end
  end

  # Soft emoji sigil from unit + name keywords — no DB column yet.
  # More specific categories win (language before generic "study").
  def habit_sigil(habit)
    case habit_sigil_icon(habit)
    when "speech" then "🗣"
    when "footsteps" then "🥾"
    when "dumbbell" then "💪"
    when "self" then "🧘"
    when "drop" then "💧"
    when "moon" then "🛏"
    when "flag" then "✍️"
    when "book" then "📖"
    when "coin" then "💰"
    when "clock" then "⏱"
    when "sprout" then "🌱"
    else "🌱"
    end
  end

  # Line-icon name for Today Habits (maps to shared/lp_icon). Never "check".
  def habit_sigil_icon(habit)
    name = habit.name.to_s.downcase
    unit = habit.unit.to_s.downcase
    blob = "#{unit} #{name}"

    return "speech" if name.match?(/german|spanish|french|italian|language|duolingo|\bduo\b|speak|vocab|anki/) ||
                       unit.match?(/duo|word|phrase|lesson|flashcard/)
    return "footsteps" if blob.match?(/step|walk|hike|run|jog|mile|km\b/)
    return "dumbbell" if blob.match?(/rep|push.?up|pull.?up|squat|lift|workout|exercise|gym|plank|burpee/)
    return "self" if blob.match?(/meditat|breath|mindful|yoga|zen/)
    return "drop" if blob.match?(/water|hydrat|glass|cup|\bdrink\b/)
    return "moon" if blob.match?(/sleep|bedtime|\brest\b|\bnaps?\b/)
    return "flag" if blob.match?(/writ|journal|essay|draft|blog/)
    return "book" if blob.match?(/page|read|book|\bstudy\b/)
    return "coin" if blob.match?(/money|€|\$|£|spend|budget|save/)
    return "clock" if unit.match?(/\bmins?\b|\bminutes?\b|\bhours?\b/) ||
                      name.match?(/\bminute|\bhour\b|\btimer\b/)

    "sprout"
  end

  def today_greeting_for(user)
    zone = Time.find_zone!(Battles::WinsOnLocalDate.time_zone_for(user))
    hour = Time.current.in_time_zone(zone).hour
    name = user.display_name
    key =
      case hour
      when 5..11 then "dash.today_bar.greeting_morning"
      when 12..16 then "dash.today_bar.greeting_afternoon"
      else "dash.today_bar.greeting_evening"
      end
    I18n.t(key, name: name)
  end

  def today_local_date_label(user)
    zone = Time.find_zone!(Battles::WinsOnLocalDate.time_zone_for(user))
    Time.current.in_time_zone(zone).to_date.strftime("%A, %-d %b")
  end

  def home_grid_style(count)
    cols = case count
    when 1 then 1
    when 2 then 2
    when 3, 4 then 2
    when 5, 6 then 3
    when 7, 8, 9 then 3
    else 4
    end

    "grid-template-columns: repeat(#{cols}, minmax(0, 1fr));"
  end

  def nav_link_class(active)
    studio_nav_class(active)
  end

  def studio_nav_class(active)
    base = "studio-nav-link"
    active ? "#{base} is-active" : base
  end

  def studio_tab_class(active)
    base = "studio-tab"
    active ? "#{base} is-active" : base
  end

  def locale_options
    [
      { code: :en, short: "EN", flag: "🇬🇧" },
      { code: :de, short: "DE", flag: "🇩🇪" },
      { code: :es, short: "ES", flag: "🇪🇸" },
      { code: :lv, short: "LV", flag: "🇱🇻" },
      { code: :ru, short: "RU", flag: "🇷🇺" }
    ]
  end

  def current_locale_option
    locale_options.find { |opt| opt[:code] == I18n.locale } || locale_options.first
  end

  def end_of_day_recap_stats(health)
    return "" if health.blank?

    if health.hp.to_i >= 100
      t("dash.end_of_day.recap_stats.full_health",
        count: health.total_count,
        done: health.done_count,
        total: health.total_count)
    else
      t("dash.end_of_day.recap_stats.partial_health",
        count: health.total_count,
        done: health.done_count,
        total: health.total_count)
    end
  end

  def end_of_day_share_text(health, user: current_user)
    return "" if health.blank?

    t("dash.end_of_day.share_recap", count: health.done_count, url: referral_share_url(user))
  end

  def end_of_day_battles_won_line(health)
    return "" if health.blank?

    t("dash.end_of_day.steps.win.battles_won", count: health.done_count)
  end

  def end_of_day_recap_camp_line(progress)
    progress ||= {}
    total = progress[:camps_total].to_i
    return "" if total <= 0

    current_camp = [ progress[:camps_completed].to_i + 1, total ].min
    t("dash.end_of_day.steps.win.camp_line",
      current: current_camp,
      total: total,
      label: progress[:ridge_label])
  end

  def end_of_day_mountain_progress(strategy_goal, mountain)
    mountain ||= { progress: 0, label: "" }
    return { percent: mountain[:progress].to_i, camps_completed: 0, camps_total: 0, ridge_label: mountain[:label] } if strategy_goal.blank?

    plans = strategy_goal.children.select { |child| child.plan? && !child.holding? }
    projects = plans.flat_map { |plan| plan.children.select { |child| child.project? && !child.holding? } }
    {
      percent: mountain[:progress].to_i,
      camps_completed: projects.count(&:completed?),
      camps_total: projects.size,
      ridge_label: mountain[:label]
    }
  end

  def end_of_day_mountain_meta(progress)
    progress ||= {}
    total = progress[:camps_total].to_i
    if total.positive?
      current_camp = [ progress[:camps_completed].to_i + 1, total ].min
      t("dash.end_of_day.steps.closed.mountain_meta",
        current: current_camp,
        total: total,
        label: progress[:ridge_label].to_s)
    else
      progress[:ridge_label].to_s
    end
  end

  def end_of_day_signoff_camp(progress)
    progress ||= {}
    total = progress[:camps_total].to_i
    return nil if total <= 0

    current = [ progress[:camps_completed].to_i + 1, total ].min
    percent = ((current.to_f / total) * 100).round.clamp(0, 100)
    {
      current: current,
      total: total,
      percent: percent,
      label: t("dash.end_of_day.steps.closed.camp_of", current: current, total: total)
    }
  end

  def active_goal_title(strategy_goal: nil, journey: nil)
    strategy_goal&.title.presence || journey&.title || t("dash.active_goal_fallback")
  end

  # Tiny thumb for the Today other-mountains dropdown (custom mountain_photo only).
  def other_mountain_thumb_url(journey)
    return nil unless journey&.mountain_photo&.attached?

    url_for(journey.mountain_photo.variant(resize_to_limit: [ 72, 72 ]))
  rescue StandardError
    url_for(journey.mountain_photo)
  end

  # Photo Today inline add row — off during first-camp reveal (Mountain link / empty CTA stay).
  # Shown when a camp exists, or a goal exists so PathProject.ensure! can use the holding camp.
  def today_inline_add_battle?(journey: nil)
    journey ||= @journey
    return false if journey.blank?
    return false if journey.first_camp_reveal_pending?

    return true if Strategy::PathProject.resolve(user: current_user, journey: journey).present?

    Goals::Current.goal_for(user: current_user, journey: journey).present?
  end

  def google_sign_in_configured?
    ENV["GOOGLE_CLIENT_ID"].to_s.strip.present? &&
      ENV["GOOGLE_CLIENT_SECRET"].to_s.strip.present?
  end

  def in_app_browser?
    ua = request.user_agent.to_s
    %w[FBAN FBAV FB_IAB FBIOS Instagram Messenger].any? { |token| ua.include?(token) }
  end

  def beta_card_visible?
    !authenticated? && !play_app?
  end

  def google_sign_in_button_visible?
    google_sign_in_configured? && !in_app_browser?
  end
end
