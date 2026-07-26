module ApplicationHelper
  def dash_momentum_line(percent)
    p = percent.to_i
    key =
      if p >= 100 then "summit"
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

  def canonical_base_url
    host = ENV["APP_HOST"].presence || (respond_to?(:request) ? request.host : "example.com")
    "https://#{host}"
  end

  def absolute_url(path)
    "#{canonical_base_url}#{path}"
  end

  # Fresh share URL so WhatsApp re-scrapes OG preview (it caches the bare homepage).
  def share_landing_url
    absolute_url("/?s=lp")
  end

  def page_meta_title
    content_for?(:title) ? content_for(:title) : "LifePoints"
  end

  def page_meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : I18n.t("landing.meta_description")
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
    InviteShareMessage.call(landing_url: share_landing_url)
  end

  def invite_share_message_body
    InviteShareMessage.body(landing_url: share_landing_url)
  end

  def format_amount(amount)
    amount = 0 if amount.blank?
    amount == amount.to_i ? amount.to_i.to_s : amount.to_s("F")
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
      { code: :lv, short: "LV", flag: "🇱🇻" }
    ]
  end
end
